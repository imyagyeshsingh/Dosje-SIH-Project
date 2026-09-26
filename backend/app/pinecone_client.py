import os

from dotenv import load_dotenv
from pinecone import Pinecone


load_dotenv()


def get_pinecone_client() -> Pinecone:
    api_key = os.getenv("PINECONE_API_KEY")
    if not api_key:
        raise RuntimeError("PINECONE_API_KEY is not configured")

    return Pinecone(api_key=api_key)
