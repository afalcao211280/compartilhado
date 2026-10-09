# 9. AI Agents: Python com Hardness Completo

## 9.1 Arquitetura de AI Agents

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AI LAYER ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   ���
│  │                    ORCHESTRATION LAYER                           │   │
│  │  ┌─────────────────────────────────────────────────────────────┐ │   │
│  │  │  CrewAI Flows Orchestrator                                  │ │   │
│  │  │  - Intent Classification                                     │ │   │
│  │  │  - Context Aggregation                                      │ │   │
│  │  │  - Agent Routing                                            │ │   │
│  │  │  - Response Synthesis                                       │ │   │
│  │  └─────────────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                              │                                          │
│  ┌───────────────────────────┼───────────────────────────────────────┐ │
│  │                    SPECIALIST AGENTS                               │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ │ │
│  │  │   Product   │ │   Order     │ │  Payment    │ │  Shipping   │ │ │
│  │  │   Agent     │ │   Agent     │ │   Agent     │ │   Agent     │ │ │
│  │  │  (CrewAI)   │ │  (CrewAI)   │ │  (CrewAI)   │ │  (CrewAI)   │ │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘ │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │ │
│  │  │   Support   │ │  Returns     │ │  General    │                │ │
│  │  │   Agent     │ │   Agent      │ │   Agent     │                │ │
│  │  │  (CrewAI)   │ │  (CrewAI)    │ │  (CrewAI)   │                │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘                │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│  ┌───────────────────────────┼───────────────────────────────────────┐ │
│  │                    RAG LAYER                                        │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │  pgvector → Product Embeddings                              │   │ │
│  │  │  pgvector → Policy Embeddings                               │   │ │
│  │  │  pgvector → Conversation History                            │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                              │                                          │
│  ┌───────────────────────────┼───────────────────────────────────────┐ │
│  │                  GUARDRAILS LAYER                                  │ │
│  │  Input Validation → LLM Processing → Output Validation            │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## 9.2 Project Structure

```
ai-platform/
├── ai_orchestrator/
│   ├── cmd/
│   │   └── server/
│   │       └── main.py
│   ├── orchestrator/
│   │   ├── flows/
│   │   │   ├── ecommerce_flow.py
│   │   │   └── intent_flow.py
│   │   └── router.py
│   ├── proto/
│   └── requirements.txt
│
├── ai_agents/
│   ├── agents/
│   │   ├── base/
│   │   │   ├── agent.py
│   │   │   └── tools.py
│   │   ├── product_agent.py
│   │   ├── order_agent.py
│   │   ├── payment_agent.py
│   │   ├── shipping_agent.py
│   │   └── support_agent.py
│   ├── tools/
│   │   ├── product_tools.py
│   │   ├── order_tools.py
│   │   ├── payment_tools.py
│   │   └── shipping_tools.py
│   └── requirements.txt
│
├── ai_guardrails/
│   ├── input/
│   │   ├── prompt_injection.py
│   │   ├── pii_detector.py
│   │   └── toxicity_filter.py
│   ├── output/
│   │   ├── fact_verifier.py
│   │   └── content_filter.py
│   ├── config.py
│   └── registry.py
│
├── ai_rag/
│   ├── indexers/
│   │   ├── product_indexer.py
│   │   └── policy_indexer.py
│   ├── retrievers/
│   │   └── semantic_retriever.py
│   └── pipeline.py
│
├── ai_core/
│   ├── memory/
│   │   └── conversation_memory.py
│   ├── llm/
│   │   └── llm_factory.py
│   └── metrics.py
│
└── tests/
    ├── agents/
    ├── guardrails/
    └── integration/
```

## 9.3 Orchestrator Implementation

```python
# ai_orchestrator/orchestrator/flows/ecommerce_flow.py
from crewai.flow.flow import Flow, start, listen, router
from crewai.flow import FlowState
from typing import Dict, Any, Literal
from langchain_openai import ChatOpenAI
import logging

logger = logging.getLogger(__name__)

llm = ChatOpenAI(model="gpt-4o", temperature=0.3)

class EcommerceFlow(Flow):
    """Main orchestration flow for e-commerce chat interactions"""
    
    def __init__(self, config: Dict[str, Any] = None):
        super().__init__()
        self.config = config or {}
        
        # Initialize agents
        self._setup_agents()
        
        # State management
        self.state: Dict[str, Any] = {}
    
    def _setup_agents(self):
        """Setup all specialist agents"""
        from ai_agents.agents import (
            ProductAgent, OrderAgent, PaymentAgent, 
            ShippingAgent, SupportAgent
        )
        
        self.product_agent = ProductAgent()
        self.order_agent = OrderAgent()
        self.payment_agent = PaymentAgent()
        self.shipping_agent = ShippingAgent()
        self.support_agent = SupportAgent()
    
    @start()
    def classify_intent(self, state: FlowState) -> FlowState:
        """Classify user intent using LLM"""
        user_message = state.get("message", "")
        history = state.get("history", [])
        
        classification_prompt = f"""Analyze this customer message and classify the intent.
        
        Available intents:
        - product_query: Questions about products, prices, availability, specs
        - order_status: Questions about order status, tracking, changes
        - payment_issue: Questions about payment, refunds, invoices
        - shipping_question: Questions about shipping, delivery, address
        - return_request: Requests for returns, exchanges
        - cancellation: Request to cancel order
        - complaint: Complaints or issues
        - general_inquiry: Other questions
        
        Conversation history:
        {self._format_history(history)}
        
        Current message: {user_message}
        
        Respond with ONLY the intent category, nothing else."""
        
        intent = llm.invoke(classification_prompt)
        intent_clean = intent.content.strip().lower().replace(" ", "_")
        
        logger.info(f"Classified intent: {intent_clean}")
        
        state["intent"] = intent_clean
        return state
    
    @router(classify_intent)
    def route_to_agent(self, state: FlowState) -> str:
        """Route to appropriate agent based on intent"""
        intent = state.get("intent", "general_inquiry")
        
        routing_map = {
            "product_query": "product",
            "order_status": "order",
            "payment_issue": "payment",
            "shipping_question": "shipping",
            "return_request": "returns",
            "cancellation": "support",  # Support handles cancellations
            "complaint": "support",
            "general_inquiry": "support",
        }
        
        return routing_map.get(intent, "support")
    
    @listen("product")
    def handle_product(self, state: FlowState) -> FlowState:
        """Handle product-related queries"""
        message = state.get("message", "")
        context = state.get("context", {})
        
        result = self.product_agent.execute(message, context)
        state["response"] = result
        state["agent"] = "product"
        state["suggested_actions"] = self.product_agent.get_suggestions()
        
        return state
    
    @listen("order")
    def handle_order(self, state: FlowState) -> FlowState:
        """Handle order-related queries"""
        message = state.get("message", "")
        context = state.get("context", {})
        user_id = state.get("user_id")
        
        result = self.order_agent.execute(message, context, user_id)
        state["response"] = result
        state["agent"] = "order"
        state["suggested_actions"] = self.order_agent.get_suggestions()
        
        return state
    
    @listen("support")
    def handle_support(self, state: FlowState) -> FlowState:
        """Handle general support requests"""
        message = state.get("message", "")
        context = state.get("context", {})
        
        result = self.support_agent.execute(message, context)
        state["response"] = result
        state["agent"] = "support"
        state["suggested_actions"] = self.support_agent.get_suggestions()
        
        return state
    
    # ... handlers for payment, shipping, returns
    
    def _format_history(self, history: list) -> str:
        """Format conversation history for LLM context"""
        if not history:
            return "No previous conversation"
        
        formatted = []
        for msg in history[-5:]:  # Last 5 messages
            role = msg.get("role", "user")
            content = msg.get("content", "")
            formatted.append(f"{role.upper()}: {content}")
        
        return "\n".join(formatted)
    
    def process(self, message: str, user_id: str = None, history: list = None) -> Dict[str, Any]:
        """Main entry point for processing messages"""
        state = FlowState(
            message=message,
            user_id=user_id,
            history=history or [],
            context={}
        )
        
        result = self.kickoff(initial_state=state)
        
        return {
            "response": result.get("response", ""),
            "agent": result.get("agent", "unknown"),
            "suggested_actions": result.get("suggested_actions", []),
            "escalate": result.get("escalate", False),
        }
```

## 9.4 Specialist Agents

```python
# ai_agents/agents/product_agent.py
from crewai import Agent
from crewai.tools import tool
from typing import Dict, Any
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o", temperature=0.2)

class ProductAgent:
    """Specialist agent for product-related queries"""
    
    def __init__(self):
        self.agent = Agent(
            role="Especialista em Produtos",
            goal=(
                "Auxiliar clientes com informações precisas sobre produtos de e-commerce, "
                "incluindo descrições, preços, disponibilidade, especificações técnicas, "
                "comparações entre produtos e recomendações personalizadas."
            ),
            backstory=(
                "Você é um expert em nosso catálogo de produtos. "
                "Você conhece cada produto em detalhes, incluindo specs técnicas, "
                "reviews de clientes, disponibilidade de estoque e políticas de venda. "
                "Seu objetivo é ajudar clientes a encontrar exatamente o que procuram, "
                "respondendo de forma clara, precisa e amigável."
            ),
            llm=llm,
            tools=[
                search_products,
                get_product_details,
                check_availability,
                get_product_specs,
                compare_products,
                get_recommendations,
                get_product_reviews,
            ],
            verbose=True,
            allow_delegation=False,
        )
        self._last_suggestions = []
    
    def execute(self, message: str, context: Dict[str, Any]) -> str:
        """Execute the agent with given message"""
        result = self.agent.kickoff(inputs={
            "user_message": message,
            "context": context
        })
        
        # Extract suggestions from result
        self._last_suggestions = self._extract_suggestions(result)
        
        return result.raw if hasattr(result, 'raw') else str(result)
    
    def get_suggestions(self) -> list:
        """Get suggested follow-up actions"""
        return self._last_suggestions
    
    def _extract_suggestions(self, result) -> list:
        """Extract suggested actions from agent result"""
        # Parse agent output for suggestion patterns
        suggestions = []
        # Implementation depends on output format
        return suggestions

@tool
def search_products(query: str, filters: Dict[str, Any] = None) -> str:
    """Search for products by query string"""
    # Implementation using Elasticsearch client
    from ai_agents.tools.product_tools import ProductSearchTool
    
    search_tool = ProductSearchTool()
    results = search_tool.execute(query, filters)
    
    if not results:
        return "Nenhum produto encontrado para sua busca."
    
    formatted = ["Produtos encontrados:\n"]
    for product in results[:5]:
        formatted.append(
            f"- **{product['name']}**\n"
            f"  Preço: R$ {product['price']}\n"
            f"  SKU: {product['sku']}\n"
        )
    
    return "\n".join(formatted)

@tool
def get_product_details(product_id: str) -> str:
    """Get detailed information about a specific product"""
    from ai_agents.tools.product_tools import ProductDetailsTool
    
    details_tool = ProductDetailsTool()
    product = details_tool.execute(product_id)
    
    if not product:
        return "Produto não encontrado."
    
    return (
        f"**{product['name']}**\n\n"
        f"**Preço:** R$ {product['price']}\n"
        f"**Descrição:** {product['description']}\n"
        f"**Disponibilidade:** {'Em estoque' if product['inventory'] > 0 else 'Fora de estoque'}\n"
    )

@tool
def check_availability(product_id: str, variant_id: str = None) -> str:
    """Check product availability"""
    from ai_agents.tools.product_tools import InventoryTool
    
    inventory_tool = InventoryTool()
    available, quantity = inventory_tool.check(product_id, variant_id)
    
    if available:
        return f"Produto disponível! Temos {quantity} unidades em estoque."
    return "Produto fora de estoque no momento."
```

## 9.5 Tool Implementations

```python
# ai_agents/tools/product_tools.py
import grpc
from typing import Dict, Any, List, Optional
import logging

logger = logging.getLogger(__name__)

class ProductSearchTool:
    """Tool for searching products"""
    
    def __init__(self):
        self.es_client = None  # Elasticsearch client
        self.grpc_channel = None  # Product service gRPC channel
    
    def execute(self, query: str, filters: Dict[str, Any] = None) -> List[Dict]:
        """Execute product search"""
        try:
            # Build Elasticsearch query
            es_query = {
                "bool": {
                    "must": [
                        {
                            "multi_match": {
                                "query": query,
                                "fields": ["name^3", "description^2", "brand", "category"],
                                "fuzziness": "AUTO"
                            }
                        }
                    ]
                }
            }
            
            # Apply filters
            if filters:
                if filters.get("category"):
                    es_query["bool"]["filter"] = [
                        {"term": {"category_id": filters["category"]}}
                    ]
                if filters.get("min_price"):
                    es_query["bool"]["filter"] = [
                        {"range": {"price": {"gte": filters["min_price"]}}}
                    ]
                if filters.get("max_price"):
                    es_query["bool"]["filter"] = [
                        {"range": {"price": {"lte": filters["max_price"]}}}
                    ]
            
            # Execute search
            results = self.es_client.search(
                index="products",
                query=es_query,
                size=10
            )
            
            return [
                {
                    "id": hit["_id"],
                    "name": hit["_source"]["name"],
                    "price": hit["_source"]["price"],
                    "sku": hit["_source"]["sku"],
                    "image": hit["_source"].get("images", [None])[0],
                }
                for hit in results["hits"]["hits"]
            ]
            
        except Exception as e:
            logger.error(f"Product search failed: {e}")
            return []

class ProductDetailsTool:
    """Tool for getting product details"""
    
    def __init__(self):
        self.product_stub = None  # gRPC stub
    
    def execute(self, product_id: str) -> Optional[Dict]:
        """Get product details by ID"""
        try:
            # Try gRPC first
            if self.product_stub:
                response = self.product_stub.GetProduct(
                    pb.GetProductRequest(id=product_id)
                )
                return {
                    "id": response.product.id,
                    "name": response.product.name,
                    "description": response.product.description,
                    "price": float(response.product.price),
                    "inventory": response.product.inventory,
                    "images": [img.url for img in response.product.images],
                    "specs": dict(response.product.attributes),
                }
            
            # Fallback to REST
            import requests
            response = requests.get(f"{API_URL}/products/{product_id}")
            return response.json()
            
        except Exception as e:
            logger.error(f"Failed to get product details: {e}")
            return None
```

## 9.6 Conversation Memory

```python
# ai_core/memory/conversation_memory.py
from langchain.memory import ConversationBufferMemory
from langchain.schema import HumanMessage, AIMessage
from typing import List, Dict, Any
import json
from datetime import datetime

class ConversationMemory:
    """Manages conversation history with persistence"""
    
    def __init__(
        self,
        session_id: str,
        max_messages: int = 20,
        max_tokens: int = 4000,
        persist_to_db: bool = True
    ):
        self.session_id = session_id
        self.max_messages = max_messages
        self.max_tokens = max_tokens
        self.persist_to_db = persist_to_db
        
        self.memory = ConversationBufferMemory(
            return_messages=True,
            memory_key="chat_history",
            max_token_limit=max_tokens
        )
    
    def add_user_message(self, message: str):
        """Add user message to history"""
        self.memory.chat_memory.add_user_message(message)
        self._cleanup_if_needed()
        
        if self.persist_to_db:
            self._persist_message("user", message)
    
    def add_ai_message(self, message: str):
        """Add AI response to history"""
        self.memory.chat_memory.add_ai_message(message)
        self._cleanup_if_needed()
        
        if self.persist_to_db:
            self._persist_message("assistant", message)
    
    def get_context_for_llm(self) -> List[Dict[str, str]]:
        """Get formatted context for LLM"""
        messages = self.memory.chat_memory.messages[-self.max_messages:]
        return [
            {
                "role": "user" if isinstance(m, HumanMessage) else "assistant",
                "content": m.content
            }
            for m in messages
        ]
    
    def get_recent_context(self, n: int = 5) -> str:
        """Get recent conversation as formatted string"""
        messages = self.memory.chat_memory.messages[-n*2:]
        formatted = []
        
        for m in messages:
            role = "Cliente" if isinstance(m, HumanMessage) else "Assistente"
            formatted.append(f"{role}: {m.content}")
        
        return "\n\n".join(formatted)
    
    def _cleanup_if_needed(self):
        """Remove old messages if exceeding limits"""
        while len(self.memory.chat_memory.messages) > self.max_messages:
            self.memory.chat_memory.messages.pop(0)
    
    def _persist_message(self, role: str, content: str):
        """Persist message to database"""
        from ai_core.database import get_vector_db
        
        # Save to PostgreSQL for history
        # Save to vector DB for RAG
        
        # This would typically use async to not block
        try:
            from ai_core.database import save_message
            save_message(
                session_id=self.session_id,
                role=role,
                content=content,
                timestamp=datetime.now()
            )
        except Exception as e:
            logger.warning(f"Failed to persist message: {e}")
    
    def clear(self):
        """Clear all history"""
        self.memory.clear()
```

## 9.7 LLM Factory

```python
# ai_core/llm/llm_factory.py
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_anthropic import ChatAnthropic
from typing import Dict, Optional
import os

class LLMFactory:
    """Factory for creating LLM instances"""
    
    _instances: Dict[str, any] = {}
    
    @classmethod
    def get_llm(
        cls,
        provider: str = "openai",
        model: str = "gpt-4o",
        temperature: float = 0.3,
        **kwargs
    ):
        """Get or create LLM instance"""
        key = f"{provider}:{model}:{temperature}"
        
        if key not in cls._instances:
            cls._instances[key] = cls._create_llm(provider, model, temperature, **kwargs)
        
        return cls._instances[key]
    
    @classmethod
    def _create_llm(cls, provider: str, model: str, temperature: float, **kwargs):
        """Create new LLM instance"""
        if provider == "openai":
            return ChatOpenAI(
                model=model,
                temperature=temperature,
                api_key=os.getenv("OPENAI_API_KEY"),
                **kwargs
            )
        elif provider == "anthropic":
            return ChatAnthropic(
                model=model,
                temperature=temperature,
                api_key=os.getenv("ANTHROPIC_API_KEY"),
                **kwargs
            )
        elif provider == "local":
            # For local models (vLLM, Ollama)
            return ChatOpenAI(
                model=model,
                temperature=temperature,
                openai_api_base=os.getenv("LOCAL_LLM_URL", "http://localhost:8000"),
                **kwargs
            )
        else:
            raise ValueError(f"Unknown provider: {provider}")
    
    @classmethod
    def get_embeddings(cls, provider: str = "openai", model: str = "text-embedding-3-small"):
        """Get embeddings model"""
        if provider == "openai":
            return OpenAIEmbeddings(
                model=model,
                api_key=os.getenv("OPENAI_API_KEY")
            )
        else:
            raise ValueError(f"Unsupported embeddings provider: {provider}")
```

## 9.8 Testing

```python
# tests/agents/test_product_agent.py
import pytest
from ai_agents.agents.product_agent import ProductAgent
from unittest.mock import Mock, patch

class TestProductAgent:
    @pytest.fixture
    def agent(self):
        return ProductAgent()
    
    @pytest.fixture
    def mock_tools(self):
        with patch('ai_agents.agents.product_agent.search_products') as mock:
            mock.return_value = "Mock search results"
            yield mock
    
    def test_product_search(self, agent):
        """Test product search execution"""
        result = agent.execute(
            message="Qual o preço do iPhone 15?",
            context={}
        )
        
        assert result is not None
        assert isinstance(result, str)
        assert len(result) > 0
    
    def test_product_not_found(self, agent):
        """Test handling of product not found"""
        with patch('ai_agents.tools.product_tools.ProductSearchTool.execute') as mock:
            mock.return_value = []
            
            result = agent.execute(
                message="Search for nonexistent product xyz123",
                context={}
            )
            
            # Agent should handle gracefully
            assert result is not None
    
    def test_suggestions_generated(self, agent):
        """Test that suggestions are generated"""
        agent.execute(
            message="Quero um celular para jogar",
            context={}
        )
        
        suggestions = agent.get_suggestions()
        # Should have suggestions based on context
        assert isinstance(suggestions, list)

class TestOrchestrator:
    @pytest.fixture
    def orchestrator(self):
        from ai_orchestrator.orchestrator.flows.ecommerce_flow import EcommerceFlow
        return EcommerceFlow()
    
    def test_intent_classification(self, orchestrator):
        """Test intent classification"""
        from crewai.flow import FlowState
        
        state = FlowState(
            message="Quero saber o status do meu pedido",
            history=[]
        )
        
        result = orchestrator.classify_intent(state)
        
        assert result["intent"] == "order_status"
    
    def test_routing(self, orchestrator):
        """Test agent routing"""
        state = {"intent": "product_query"}
        
        route = orchestrator.route_to_agent(state)
        
        assert route == "product"
    
    def test_full_process(self, orchestrator):
        """Test full message processing"""
        result = orchestrator.process(
            message="Qual o preço do produto XYZ?",
            user_id="user123",
            history=[]
        )
        
        assert "response" in result
        assert "agent" in result
        assert isinstance(result["response"], str)
```

## 9.9 Environment Configuration

```yaml
# ai-platform/config.yaml
ai:
  orchestrator:
    model: gpt-4o
    temperature: 0.3
    max_tokens: 1000
  
  agents:
    product:
      model: gpt-4o
      temperature: 0.2
      tools: [search, details, availability, specs]
    
    order:
      model: gpt-4o
      temperature: 0.1
      tools: [lookup, status, cancel]
    
    # ... other agents
  
  guardrails:
    enabled: true
    input:
      max_length: 2000
      prompt_injection_threshold: 0.7
      pii_masking: true
    
    output:
      max_length: 2000
      fact_check: true
  
  memory:
    max_messages: 20
    max_tokens: 4000
    persist: true

  rag:
    vector_db: pgvector
    collection_products: product_knowledge
    collection_policies: policy_knowledge
    top_k: 5
    similarity_threshold: 0.7

database:
  host: ${DB_HOST}
  port: 5432
  name: ai_platform
  user: ${DB_USER}
  password: ${DB_PASSWORD}

redis:
  host: ${REDIS_HOST}
  port: 6379
  db: 0
```