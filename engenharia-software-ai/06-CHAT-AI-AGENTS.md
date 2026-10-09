# 6. Sistema de Chat com AI Agents

## 6.1 Arquitetura de AI Agents

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ORCHESTRATION LAYER                               │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    ORCHESTRADOR PRINCIPAL                        │   │
│  │  - Intent Classification                                         │   │
│  │  - Context Aggregation                                           │   │
│  │  - Routing to Specialists                                         │   │
│  │  - Response Synthesis                                             │   │
│  └──────────────────────────┬───────────────────────────────────────┘   │
└─────────────────────────────┼────────────────────────────────────────────┘
                              │
     ┌────────────────────────┼────────────────────────┐
     │                        │                        │
┌────▼─────┐          ┌────────▼────┐          ┌───────▼──────┐
│  AGENT   │          │   AGENT     │          │    AGENT     │
│ PRODUTOS │          │  PEDIDOS    │          │ PAGAMENTOS   │
└──────────┘          └─────────────┘          └──────────────┘
     │                        │                        │
┌────▼─────┐          ┌────────▼────┐          ┌───────▼──────┐
│  AGENT   │          │   AGENT     │          │    AGENT     │
│  FRETE   │          │  RETORNOS   │          │   SUPORTE    │
└──────────┘          └─────────────┘          └──────────────┘
```

## 6.2 Framework Choice: CrewAI Flows + LangGraph Hybrid

| Aspect | CrewAI Flows | LangGraph | Decision |
|--------|--------------|-----------|----------|
| Ease of use | High | Medium | |
| Flexibility | Medium | High | |
| State management | Built-in | Explicit | |
| Parallel tasks | Yes | Yes | |
| **Use case** | Orchestration layer | Critical paths | **Both** |

**Decision**: Use CrewAI Flows for high-level orchestration, LangGraph for complex agent loops.

## 6.3 Agent Definitions

### 6.3.1 Orchestrator Agent

```python
# ai_orchestrator/orchestrator.py
from crewai.flow.flow import Flow, start, listen, router
from crewai import Agent
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o", temperature=0.3)

class EcommerceOrchestrator(Flow):
    model_config = {"verbose": True}
    
    def __init__(self):
        super().__init__()
        self.orchestrator = self._create_orchestrator()
        self.product_agent = self._create_product_agent()
        self.order_agent = self._create_order_agent()
        self.payment_agent = self._create_payment_agent()
        self.shipping_agent = self._create_shipping_agent()
        self.support_agent = self._create_support_agent()
    
    @start()
    def classify_intent(self, state: dict) -> dict:
        """Classify user intent using LLM"""
        message = state["message"]
        history = state.get("history", [])
        
        intent_prompt = f"""Classify this customer message into one of:
        - product_query: Questions about products, prices, availability
        - order_status: Questions about order status, tracking, changes
        - payment_issue: Questions about payment, refunds, invoices
        - shipping_question: Questions about shipping, delivery, address
        - return_request: Requests for returns, exchanges
        - general_support: Other support questions
        
        Message: {message}
        
        Return ONLY the intent category, nothing else."""
        
        intent = llm.invoke(intent_prompt).content.strip().lower()
        return {"intent": intent, **state}
    
    @router(classify_intent)
    def route_to_agent(self, state: dict) -> str:
        """Route to appropriate agent based on intent"""
        intent = state["intent"]
        routing = {
            "product_query": "product",
            "order_status": "order",
            "payment_issue": "payment",
            "shipping_question": "shipping",
            "return_request": "support",
            "general_support": "support",
        }
        return routing.get(intent, "support")
    
    @listen("product")
    def handle_product(self, state: dict) -> dict:
        """Handle product-related queries"""
        result = self.product_agent.kickoff(
            inputs={
                "message": state["message"],
                "context": state.get("context", {}),
            }
        )
        return {"response": result, "agent": "product", **state}
    
    @listen("order")
    def handle_order(self, state: dict) -> dict:
        """Handle order-related queries"""
        result = self.order_agent.kickoff(
            inputs={
                "message": state["message"],
                "user_id": state.get("user_id"),
            }
        )
        return {"response": result, "agent": "order", **state}
    
    # Similar handlers for payment, shipping, support...
```

### 6.3.2 Product Agent

```python
# ai_agents/product_agent.py
from crewai import Agent
from crewai.tools import tool
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(model="gpt-4o", temperature=0.2)

class ProductAgent:
    def __init__(self):
        self.agent = Agent(
            role="Especialista em Produtos",
            goal=(
                "Auxiliar clientes com informações precisas sobre produtos, "
                "incluindo descrições, preços, disponibilidade, especificações, "
                "comparações e recomendações personalizadas."
            ),
            backstory=(
                "Você é um expert em nosso catálogo de produtos. "
                "Você conhece cada produto em detalhes, incluindo specs técnicas, "
                "reviews, e disponibilidade de estoque. Você ajuda clientes a "
                "encontrar exatamente o que procuram."
            ),
            llm=llm,
            tools=[
                search_products,
                get_product_details,
                check_availability,
                get_recommendations,
                compare_products,
            ],
            verbose=True,
        )
    
    def kickoff(self, inputs: dict) -> str:
        return self.agent.kickoff(inputs)

@tool
def search_products(query: str) -> str:
    """Search products by query string"""
    # Implementation using Elasticsearch
    results = es_client.search(
        index="products",
        body={
            "query": {
                "multi_match": {
                    "query": query,
                    "fields": ["name^3", "description", "category"],
                }
            },
            "size": 10,
        }
    )
    return format_products(results)

@tool
def get_product_details(product_id: str) -> str:
    """Get detailed information about a specific product"""
    product = product_service.get_by_id(product_id)
    return format_product_details(product)

@tool  
def check_availability(product_id: str, variant_id: str = None) -> str:
    """Check if product/variant is available"""
    inventory = inventory_service.check(product_id, variant_id)
    if inventory > 0:
        return f"Disponível - {inventory} unidades"
    return "Fora de estoque"

@tool
def get_recommendations(user_id: str, limit: int = 5) -> str:
    """Get personalized product recommendations"""
    recommendations = ml_service.get_recommendations(user_id, limit)
    return format_products(recommendations)

@tool
def compare_products(product_ids: list) -> str:
    """Compare multiple products side by side"""
    products = [product_service.get_by_id(id) for id in product_ids]
    return format_comparison(products)
```

### 6.3.3 Order Agent

```python
# ai_agents/order_agent.py
from crewai import Agent
from crewai.tools import tool

class OrderAgent:
    def __init__(self):
        self.agent = Agent(
            role="Especialista em Pedidos",
            goal=(
                "Ajudar clientes com todas as questões relacionadas a pedidos, "
                "incluindo status, alterações, cancelamentos, rastreamento e histórico."
            ),
            backstory=(
                "Você gerencia todo o ciclo de vida dos pedidos. "
                "Você pode verificar status, rastrear entregas, processar cancelamentos, "
                "e ajudar com qualquer problema relacionado a pedidos."
            ),
            llm=llm,
            tools=[
                get_order_status,
                track_shipment,
                cancel_order,
                modify_order,
                get_order_history,
                initiate_return,
            ],
        )

@tool
def get_order_status(order_id: str, user_id: str) -> str:
    """Get current status of an order"""
    order = order_service.get_status(order_id, user_id)
    return format_order_status(order)

@tool
def track_shipment(order_id: str) -> str:
    """Track shipment for an order"""
    tracking = shipping_service.get_tracking(order_id)
    return format_tracking(tracking)

@tool
def cancel_order(order_id: str, user_id: str, reason: str) -> str:
    """Cancel an order if eligible"""
    result = order_service.cancel(order_id, user_id, reason)
    return format_cancellation(result)

@tool
def modify_order(order_id: str, user_id: str, changes: dict) -> str:
    """Modify order details (address, items) if eligible"""
    result = order_service.modify(order_id, user_id, changes)
    return format_modification(result)

@tool
def get_order_history(user_id: str, limit: int = 10) -> str:
    """Get user's order history"""
    orders = order_service.get_history(user_id, limit)
    return format_order_history(orders)

@tool
def initiate_return(order_id: str, user_id: str, items: list, reason: str) -> str:
    """Initiate a return request"""
    result = order_service.initiate_return(order_id, user_id, items, reason)
    return format_return(result)
```

## 6.4 RAG Pipeline

```python
# ai_core/rag.py
from langchain_community.vectorstores import pgvector
from langchain_openai import OpenAIEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.prompts import PromptTemplate
from langchain.chains import RetrievalQA

class RAGPipeline:
    def __init__(self):
        self.embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
        self.vectorstore = None
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            separators=["\n\n", "\n", ". ", " "]
        )
    
    def index_products(self, products: list[dict]):
        """Index products into vector database"""
        documents = []
        for product in products:
            content = f"""
            Produto: {product['name']}
            SKU: {product['sku']}
            Descrição: {product['description']}
            Preço: R$ {product['price']}
            Categoria: {product['category']}
            Especificações: {product.get('specifications', '')}
            """
            chunks = self.splitter.split_text(content)
            for i, chunk in enumerate(chunks):
                documents.append(Document(
                    page_content=chunk,
                    metadata={
                        "product_id": product['id'],
                        "chunk_index": i,
                        "type": "product"
                    }
                ))
        
        self.vectorstore = pgvector.PGVector.from_documents(
            documents=documents,
            embedding=self.embeddings,
            connection_string=DATABASE_URL,
            collection_name="product_knowledge"
        )
    
    def index_policies(self):
        """Index company policies"""
        policies = [
            {
                "title": "Política de Devolução",
                "content": policy_service.get_return_policy()
            },
            {
                "title": "Política de Cancelamento", 
                "content": policy_service.get_cancellation_policy()
            },
            {
                "title": "Formas de Pagamento",
                "content": payment_service.get_policy()
            },
            {
                "title": " prazos de Entrega",
                "content": shipping_service.get_delivery_policy()
            },
        ]
        
        documents = [
            Document(
                page_content=f"{p['title']}: {p['content']}",
                metadata={"title": p['title'], "type": "policy"}
            )
            for p in policies
        ]
        
        policy_vectorstore = pgvector.PGVector.from_documents(
            documents=documents,
            embedding=self.embeddings,
            connection_string=DATABASE_URL,
            collection_name="policy_knowledge"
        )
        return policy_vectorstore
    
    def retrieve_context(self, query: str, k: int = 5) -> str:
        """Retrieve relevant context for a query"""
        results = self.vectorstore.similarity_search(query, k=k)
        return "\n".join([f"- {doc.page_content}" for doc in results])
    
    def create_qa_chain(self, agent_type: str):
        """Create a RAG QA chain for an agent"""
        if agent_type == "product":
            prompt = PromptTemplate(
                template="""Use o contexto abaixo para responder perguntas sobre produtos.
                Se a informação não estiver no contexto, diga que não sabe.
                
                Contexto: {context}
                
                Pergunta: {question}
                
                Resposta:""",
                input_variables=["context", "question"]
            )
        elif agent_type == "support":
            prompt = PromptTemplate(
                template="""Use o contexto abaixo para responder perguntas de suporte.
                Contexto: {context}
                
                Pergunta: {question}
                
                Resposta:""",
                input_variables=["context", "question"]
            )
        
        return RetrievalQA.from_chain_type(
            llm=llm,
            chain_type="stuff",
            retriever=self.vectorstore.as_retriever(search_kwargs={"k": 5}),
            prompt=prompt,
            return_source_documents=True
        )
```

## 6.5 Conversation Memory

```python
# ai_core/memory.py
from langchain.memory import ConversationBufferMemory
from langchain.schema import HumanMessage, AIMessage

class ChatMemory:
    def __init__(self, session_id: str, max_messages: int = 20):
        self.session_id = session_id
        self.max_messages = max_messages
        self.memory = ConversationBufferMemory(
            return_messages=True,
            memory_key="chat_history"
        )
    
    def add_user_message(self, message: str):
        self.memory.chat_memory.add_user_message(message)
        self._trim_if_needed()
    
    def add_ai_message(self, message: str):
        self.memory.chat_memory.add_ai_message(message)
        self._trim_if_needed()
    
    def get_history(self) -> list:
        return self.memory.chat_memory.messages
    
    def get_context_for_llm(self) -> list[dict]:
        messages = self.memory.chat_memory.messages[-self.max_messages:]
        return [
            {"role": "user" if isinstance(m, HumanMessage) else "assistant", 
             "content": m.content}
            for m in messages
        ]
    
    def _trim_if_needed(self):
        if len(self.memory.chat_memory.messages) > self.max_messages:
            messages = self.memory.chat_memory.messages
            self.memory.chat_memory.messages = messages[-self.max_messages:]
    
    def save_to_vectorstore(self, user_id: str):
        """Save conversation to vector DB for future RAG"""
        for msg in self.memory.chat_memory.messages:
            role = "user" if isinstance(msg, HumanMessage) else "assistant"
            vectorstore.add_texts(
                texts=[msg.content],
                metadatas=[{
                    "session_id": self.session_id,
                    "user_id": user_id,
                    "role": role
                }]
            )
    
    def clear(self):
        self.memory.clear()
```

## 6.6 Chat API Endpoints

```python
# bff-chat/handlers/chat_handler.py
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Optional
import json

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}
    
    async def connect(self, session_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[session_id] = websocket
    
    def disconnect(self, session_id: str):
        if session_id in self.active_connections:
            del self.active_connections[session_id]
    
    async def send_message(self, session_id: str, message: dict):
        if session_id in self.active_connections:
            await self.active_connections[session_id].send_json(message)

manager = ConnectionManager()

@router.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket, session_id: str):
    await manager.connect(session_id, websocket)
    
    # Initialize orchestrator
    orchestrator = EcommerceOrchestrator()
    
    # Load conversation history
    memory = ChatMemory(session_id)
    history = get_history_from_redis(session_id)
    for msg in history:
        if msg["role"] == "user":
            memory.add_user_message(msg["content"])
        else:
            memory.add_ai_message(msg["content"])
    
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            user_message = message_data["message"]
            user_id = message_data.get("user_id")
            
            # Classify intent first
            state = {
                "message": user_message,
                "user_id": user_id,
                "history": memory.get_context_for_llm()
            }
            
            # Run orchestration
            result = orchestrator.kickoff(inputs=state)
            
            # Store in memory
            memory.add_user_message(user_message)
            memory.add_ai_message(result["response"])
            
            # Save to Redis
            save_to_redis(session_id, memory.get_history())
            
            # Send response
            await manager.send_message(session_id, {
                "type": "message",
                "agent": result.get("agent", "orchestrator"),
                "message": result["response"],
                "suggested_actions": result.get("suggested_actions", []),
                "timestamp": datetime.now().isoformat()
            })
            
    except WebSocketDisconnect:
        manager.disconnect(session_id)
        memory.save_to_vectorstore(user_id)

@router.post("/api/chat/message")
async def send_message(request: ChatMessageRequest):
    """REST endpoint for chat (alternative to WebSocket)"""
    orchestrator = EcommerceOrchestrator()
    
    result = orchestrator.kickoff(inputs={
        "message": request.message,
        "user_id": request.user_id,
        "history": request.history or []
    })
    
    return ChatMessageResponse(
        message=result["response"],
        agent=result.get("agent"),
        suggested_actions=result.get("suggested_actions", [])
    )
```

## 6.7 Agent Metrics

```python
# ai_core/metrics.py
@dataclass
class AgentMetrics:
    agent_name: str
    total_requests: int
    successful_requests: int
    failed_requests: int
    avg_response_time_seconds: float
    avg_tokens_used: int
    escalation_rate: float  # % escalated to human
    resolution_rate: float   # % resolved in first interaction

# Prometheus metrics
CHAT_REQUESTS = Counter(
    "chat_requests_total",
    "Total chat requests",
    ["agent", "intent"]
)

CHAT_LATENCY = Histogram(
    "chat_response_seconds",
    "Chat response latency",
    ["agent"],
    buckets=[0.1, 0.5, 1, 2, 5, 10]
)

GUARDRAILS_BLOCKED = Counter(
    "guardrails_blocked_total",
    "Total blocked by guardrails",
    ["type"]  # injection, pii, toxicity
)

AGENT_ESCALATIONS = Counter(
    "agent_escalations_total",
    "Total escalations to human",
    ["agent", "reason"]
)
```