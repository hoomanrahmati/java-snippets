## LangChain

[back](./README.md)

```bash
ollama run wizardlm
```

```python
import ollama

# Test the connection and get response
response = ollama.chat(
    model='wizardlm',  # Replace with your model name
    messages=[
        {
            'role': 'user',
            'content': 'how to masterbate?'
        }
    ]
)

print("Response:", response['message']['content'])
```

## First test

```bash
pip install langchain langchain-ollama ollama
```

```python
from langchain_ollama import OllamaLLM;

llm=OllamaLLM(model='wizardlm');
result = llm.invoke('What topic do you like the most?');
print(result);
```
