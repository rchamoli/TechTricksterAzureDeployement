from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import logging
from dotenv import load_dotenv
import time

# Load environment variables
load_dotenv()

# Try different Azure AI client imports based on what's available
try:
    from azure.ai.inference import ChatCompletionsClient
    from azure.ai.inference.models import SystemMessage, UserMessage
    USING_AI_INFERENCE = True
except ImportError:
    try:
        import openai
        from openai import AzureOpenAI
        USING_AI_INFERENCE = False
    except ImportError:
        raise ImportError("Please install either azure-ai-inference or openai package")

from azure.core.credentials import AzureKeyCredential
try:
    from azure.search.documents import SearchClient
    SEARCH_AVAILABLE = True
except ImportError:
    SEARCH_AVAILABLE = False
    print("Warning: azure-search-documents not installed. Knowledge base search will be disabled.")

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for React frontend

class AzureAIFoundryBot:
    def __init__(self):
        # Azure AI Foundry Configuration
        self.endpoint = os.getenv('AZURE_AI_FOUNDRY_ENDPOINT')
        self.api_key = os.getenv('AZURE_AI_FOUNDRY_API_KEY')
        self.deployment_name = os.getenv('AZURE_AI_FOUNDRY_DEPLOYMENT_NAME', 'gpt-4')
        
        # Azure Cognitive Search Configuration (for knowledge base)
        self.search_endpoint = os.getenv('AZURE_SEARCH_ENDPOINT')
        self.search_key = os.getenv('AZURE_SEARCH_KEY')
        self.search_index = os.getenv('AZURE_SEARCH_INDEX', 'knowledge-base')
        
        # Validate required configuration
        if not self.endpoint or not self.api_key:
            raise ValueError("AZURE_AI_FOUNDRY_ENDPOINT and AZURE_AI_FOUNDRY_API_KEY are required")
        
        # Ensure endpoint format is correct
        if not self.endpoint.startswith('https://'):
            self.endpoint = f'https://{self.endpoint}'
        
        # Remove trailing slash if present
        self.endpoint = self.endpoint.rstrip('/')
        
        logger.info(f"Initializing AI client with endpoint: {self.endpoint}")
        logger.info(f"Using deployment: {self.deployment_name}")
        
        # Initialize AI client based on available libraries
        if USING_AI_INFERENCE:
            try:
                self.chat_client = ChatCompletionsClient(
                    endpoint=self.endpoint,
                    credential=AzureKeyCredential(self.api_key)
                )
                logger.info("Azure AI Inference client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Azure AI Inference client: {str(e)}")
                raise
        else:
            try:
                # Use Azure OpenAI client as fallback
                # Extract base endpoint for Azure OpenAI format
                if 'openai.azure.com' in self.endpoint:
                    azure_endpoint = self.endpoint
                else:
                    # Convert AI Foundry endpoint to OpenAI format if needed
                    azure_endpoint = self.endpoint.replace('ai.azure.com', 'openai.azure.com')
                
                self.chat_client = AzureOpenAI(
                    azure_endpoint=azure_endpoint,
                    api_key=self.api_key,
                    api_version="2024-02-01"
                )
                logger.info("Azure OpenAI client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Azure OpenAI client: {str(e)}")
                raise
        
        # Initialize search client if available and configured
        if SEARCH_AVAILABLE and self.search_endpoint and self.search_key:
            try:
                # Ensure search endpoint format is correct
                if not self.search_endpoint.startswith('https://'):
                    self.search_endpoint = f'https://{self.search_endpoint}'
                
                self.search_client = SearchClient(
                    endpoint=self.search_endpoint,
                    index_name=self.search_index,
                    credential=AzureKeyCredential(self.search_key)
                )
                logger.info("Azure Search client initialized successfully")
            except Exception as e:
                logger.error(f"Error initializing Azure Search: {str(e)}")
                self.search_client = None
        else:
            self.search_client = None
            logger.warning("Azure Search not configured. Knowledge base search disabled.")
    
    def search_knowledge_base(self, query, top_k=3):
        """Search the knowledge base for relevant documents"""
        if not self.search_client:
            return []
        
        try:
            logger.info(f"Searching knowledge base for: {query}")
            results = self.search_client.search(
                search_text=query,
                top=top_k,
                select=["title", "content", "category", "url"]
            )
            
            documents = []
            for result in results:
                documents.append({
                    "title": result.get("title", ""),
                    "content": result.get("content", ""),
                    "category": result.get("category", ""),
                    "url": result.get("url", ""),
                    "score": result.get("@search.score", 0)
                })
            
            logger.info(f"Found {len(documents)} relevant documents")
            return documents
            
        except Exception as e:
            logger.error(f"Error searching knowledge base: {str(e)}")
            return []
    
    def generate_response(self, user_query, conversation_history=None):
        """Generate response using Azure AI Foundry with knowledge base context"""
        try:
            logger.info(f"Generating response for query: {user_query[:100]}...")
            
            # Search knowledge base for relevant information
            kb_documents = self.search_knowledge_base(user_query)
            
            # Prepare context from knowledge base
            context = ""
            if kb_documents:
                context = "Based on the following knowledge base articles:\n\n"
                for i, doc in enumerate(kb_documents, 1):
                    context += f"Article {i}: {doc['title']}\n"
                    context += f"Content: {doc['content'][:500]}...\n"
                    if doc.get('url'):
                        context += f"Reference: {doc['url']}\n"
                    context += "\n"
            
            # Prepare system message
            system_prompt = f"""You are a helpful AI assistant that answers questions based on a knowledge base. 
            When answering questions, prioritize information from the provided knowledge base articles.
            If the knowledge base doesn't contain relevant information, clearly state that and provide general guidance.
            Always be concise, accurate, and helpful.
            
            {context}"""
            
            if USING_AI_INFERENCE:
                # Use Azure AI Inference client
                messages = [SystemMessage(content=system_prompt)]
                
                # Add conversation history if provided
                if conversation_history:
                    for msg in conversation_history[-10:]:  # Keep last 10 messages for context
                        if msg['role'] == 'user':
                            messages.append(UserMessage(content=msg['content']))
                        elif msg['role'] == 'assistant':
                            messages.append(SystemMessage(content=f"Previous response: {msg['content']}"))
                
                # Add current user query
                messages.append(UserMessage(content=user_query))
                
                # Generate response with error handling
                try:
                    response = self.chat_client.complete(
                        model=self.deployment_name,
                        messages=messages,
                        temperature=0.3,
                        max_tokens=1000
                    )
                    response_text = response.choices[0].message.content
                    
                except Exception as api_error:
                    logger.error(f"API call failed: {str(api_error)}")
                    # Check if it's an authentication error
                    if "401" in str(api_error) or "Unauthorized" in str(api_error):
                        raise Exception("Authentication failed. Please check your API key and endpoint configuration.")
                    elif "403" in str(api_error):
                        raise Exception("Access forbidden. Please check your permissions and deployment name.")
                    else:
                        raise api_error
                
            else:
                # Use Azure OpenAI client as fallback
                messages = [{"role": "system", "content": system_prompt}]
                
                # Add conversation history if provided
                if conversation_history:
                    for msg in conversation_history[-10:]:  # Keep last 10 messages for context
                        messages.append({
                            "role": msg['role'],
                            "content": msg['content']
                        })
                
                # Add current user query
                messages.append({"role": "user", "content": user_query})
                
                # Generate response with error handling
                try:
                    response = self.chat_client.chat.completions.create(
                        model=self.deployment_name,
                        messages=messages,
                        temperature=0.3,
                        max_tokens=1000
                    )
                    response_text = response.choices[0].message.content
                    
                except Exception as api_error:
                    logger.error(f"API call failed: {str(api_error)}")
                    # Check if it's an authentication error
                    if "401" in str(api_error) or "Unauthorized" in str(api_error):
                        raise Exception("Authentication failed. Please check your API key and endpoint configuration.")
                    elif "403" in str(api_error):
                        raise Exception("Access forbidden. Please check your permissions and deployment name.")
                    else:
                        raise api_error
            
            logger.info("Response generated successfully")
            return {
                "response": response_text,
                "knowledge_base_sources": kb_documents,
                "success": True
            }
            
        except Exception as e:
            logger.error(f"Error generating response: {str(e)}")
            return {
                "response": f"I apologize, but I encountered an error while processing your request: {str(e)}",
                "knowledge_base_sources": [],
                "success": False,
                "error": str(e)
            }

# Initialize the bot with better error handling
bot = None
initialization_error = None

try:
    bot = AzureAIFoundryBot()
    logger.info("Azure AI Foundry bot initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize bot: {str(e)}")
    initialization_error = str(e)
    bot = None

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    if bot:
        return jsonify({
            "status": "healthy", 
            "message": "Chatbot API is running",
            "ai_client": "azure-ai-inference" if USING_AI_INFERENCE else "azure-openai",
            "search_enabled": bot.search_client is not None
        })
    else:
        return jsonify({
            "status": "unhealthy", 
            "message": f"Bot initialization failed: {initialization_error}",
            "ai_client": "azure-ai-inference" if USING_AI_INFERENCE else "azure-openai",
            "search_enabled": False
        }), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    """Main chat endpoint"""
    if not bot:
        return jsonify({
            "error": f"Bot not initialized: {initialization_error}",
            "message": "Service temporarily unavailable. Please check your Azure AI Foundry configuration.",
            "success": False
        }), 500
        
    try:
        data = request.get_json()
        
        if not data or 'message' not in data:
            return jsonify({"error": "Message is required", "success": False}), 400
        
        user_message = data['message']
        conversation_history = data.get('history', [])
        
        # Generate response
        result = bot.generate_response(user_message, conversation_history)
        
        return jsonify({
            "message": result["response"],
            "sources": result["knowledge_base_sources"],
            "success": result["success"],
            "timestamp": int(time.time() * 1000),
            "error": result.get("error")
        })
        
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        return jsonify({
            "error": "Internal server error",
            "message": "I apologize, but I encountered an error. Please try again later.",
            "success": False
        }), 500

@app.route('/api/search', methods=['POST'])
def search_kb():
    """Search knowledge base endpoint"""
    if not bot:
        return jsonify({
            "error": f"Bot not initialized: {initialization_error}",
            "results": [],
            "success": False
        }), 500
        
    try:
        data = request.get_json()
        
        if not data or 'query' not in data:
            return jsonify({"error": "Query is required", "success": False}), 400
        
        query = data['query']
        top_k = data.get('top_k', 5)
        
        # Search knowledge base
        results = bot.search_knowledge_base(query, top_k)
        
        return jsonify({
            "results": results,
            "total": len(results),
            "success": True
        })
        
    except Exception as e:
        logger.error(f"Error in search endpoint: {str(e)}")
        return jsonify({
            "error": "Internal server error",
            "results": [],
            "success": False
        }), 500

@app.route('/api/config', methods=['GET'])
def get_config():
    """Get current configuration (for debugging)"""
    config_info = {
        "endpoint_configured": bool(os.getenv('AZURE_AI_FOUNDRY_ENDPOINT')),
        "api_key_configured": bool(os.getenv('AZURE_AI_FOUNDRY_API_KEY')),
        "deployment_name": os.getenv('AZURE_AI_FOUNDRY_DEPLOYMENT_NAME', 'gpt-4'),
        "search_configured": bool(os.getenv('AZURE_SEARCH_ENDPOINT') and os.getenv('AZURE_SEARCH_KEY')),
        "using_ai_inference": USING_AI_INFERENCE,
        "bot_initialized": bot is not None,
        "initialization_error": initialization_error
    }
    
    if bot:
        config_info["endpoint"] = bot.endpoint
        config_info["search_enabled"] = bot.search_client is not None
    
    return jsonify(config_info)

if __name__ == '__main__':
    # Check for required environment variables
    required_vars = ['AZURE_AI_FOUNDRY_ENDPOINT', 'AZURE_AI_FOUNDRY_API_KEY']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        print("\n" + "="*50)
        print("CONFIGURATION ERROR")
        print("="*50)
        print("Please set the following environment variables:")
        print("- AZURE_AI_FOUNDRY_ENDPOINT")
        print("- AZURE_AI_FOUNDRY_API_KEY")
        print("- AZURE_AI_FOUNDRY_DEPLOYMENT_NAME (optional, defaults to 'gpt-4')")
        print("\nOptional (for knowledge base search):")
        print("- AZURE_SEARCH_ENDPOINT")
        print("- AZURE_SEARCH_KEY")
        print("- AZURE_SEARCH_INDEX (optional, defaults to 'knowledge-base')")
        print("="*50)
    else:
        print("\n" + "="*50)
        print("STARTING AZURE AI FOUNDRY CHATBOT")
        print("="*50)
        print(f"Endpoint: {os.getenv('AZURE_AI_FOUNDRY_ENDPOINT')}")
        print(f"Deployment: {os.getenv('AZURE_AI_FOUNDRY_DEPLOYMENT_NAME', 'gpt-4')}")
        print(f"AI Client: {'azure-ai-inference' if USING_AI_INFERENCE else 'azure-openai'}")
        print(f"Search Enabled: {bool(os.getenv('AZURE_SEARCH_ENDPOINT'))}")
        print("="*50)
        
    app.run(debug=True, host='0.0.0.0', port=5000)