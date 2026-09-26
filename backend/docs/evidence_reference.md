# Report evidence references

DoSJE stores report evidence references as external identifiers that point to evidence managed by a future EvidenceGraph or evidence-service provider.

The backend does not store embeddings, vectors, Pinecone indexes, or binary media payloads in PostgreSQL. It only keeps a provider-neutral reference back to the external evidence record.
