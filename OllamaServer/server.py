from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # be permissive for demo
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



class GenerateRequest(BaseModel):
    aslWords: list[str]


OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
OLLAMA_MODEL = "llama3"

@app.get("/")
def hello_world():
    return {"message": "Hello World"}


@app.post("/generate")
def generate_sentence(payload: GenerateRequest):
    asl = " ".join(payload.aslWords).strip()
    if not asl:
        raise HTTPException(status_code=400, detail="aslWords cannot be empty")

    try:
        response = requests.post(
            OLLAMA_URL,
            json={
                "model": OLLAMA_MODEL,
                "stream": False,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                                    "You are an ASL gloss → English translator.\n"
                                    "ASL gloss rules you MUST follow:\n"
                                    "- ASL is topic-comment: the topic comes first (e.g., STORE I GO = I go to the store)\n"
                                    "- When no subject is explicit, default to first person (I/me)\n"
                                    "- IX-YOU / YOU = you, IX-ME / ME / I = I, IX-THEY / THEY = they\n"
                                    "- Directional verbs encode subject/object: GIVE-YOU = I give you, YOU-GIVE = you give me\n"
                                    "- Time signs come first: YESTERDAY I GO STORE = I went to the store yesterday\n"
                                    "- FINISH = past tense, WILL = future tense\n"
                                    "- Repeated signs = emphasis or plurality\n"
                                    "Output ONLY one natural English sentence. No quotes, no explanation."
                                ),
                    },
                    {"role": "user", "content": f"ASL gloss: {asl}"},
                ],
                "options": {
                    "temperature": 0.2,
                    "num_predict": 50,
                },
            },
            timeout=20,
        )
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Failed to reach Ollama: {exc}") from exc

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Ollama error {response.status_code}: {response.text}",
        )

    data = response.json()
    message = (data.get("message") or {}).get("content", "").strip()

    if not message:
        raise HTTPException(status_code=502, detail="Ollama returned an empty message")

    if message.startswith('"') and message.endswith('"'):
        message = message[1:-1].strip()
    if message.startswith("'") and message.endswith("'"):
        message = message[1:-1].strip()

    return {
        "asl": asl,
        "sentence": message,
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
