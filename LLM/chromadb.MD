## Chromadb

[back](./README.md)

### embedding (default embedding)

```python
from chromadb.utils import embedding_functions;

default_ef= embedding_functions.DefaultEmbeddingFunction();

name = "What is your name?";

embed = default_ef(name);

print(embed);
```

### ollama embeding

```bash
pip install ollama
```

```python
embedding_fn= embedding_functions.OllamaEmbeddingFunction(
  model_name="???",
  url="http://localhost:11434",
  timeout=60
);
```

### Chroma Client

```python
import chromadb;
from chromadb.utils import embedding_functions;

chroma_client=chromadb.Client();
default_ef= embedding_functions.DefaultEmbeddingFunction();

collection_name = "test2_collection";
collection= chroma_client.get_or_create_collection(name=collection_name, embedding_function=default_ef);

documents=[
  {"id": "doc1", "text":"hello world"},
  {"id": "doc2", "text":"How are you today?"},
  {"id":"doc3", "text":"Goodbye, see you later"},
  {"id": "doc4", "text": "Hi universe"},
  {"id": "doc5", "text": "This is the end."},
  {"id":"doc6", "text":"Just do it"},
];

for doc in documents:
  collection.upsert(ids=[doc["id"]], documents= [doc["text"]]);

query_text= "Are you OK?";

results = collection.query(
  query_texts=[query_text],
  n_results=3
);
print(results);
print("------------------");

for index, doc in enumerate(results["documents"][0]):
  id= results["ids"][0][index];
  distance=results["distances"][0][index];
  print(
    f"id:{id}) similar document: {doc} with distance: {distance}"
  );

```

For Persistent Client

```python
chroma_client=chromadb.PersistentClient(path="./db/sample_collection");
```
