import asyncio
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List
from fastapi import WebSocket

logger = logging.getLogger(__name__)


class RealtimeConnectionManager:
    def __init__(self) -> None:
        self.active_connections: List[WebSocket] = []
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self.active_connections.append(websocket)
        logger.info("Realtime WebSocket client connected. Active: %d", len(self.active_connections))

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self._lock:
            if websocket in self.active_connections:
                self.active_connections.remove(websocket)
        logger.info("Realtime WebSocket client disconnected. Active: %d", len(self.active_connections))

    async def broadcast(self, event_name: str, data: Dict[str, Any]) -> None:
        message = {
            "event": event_name,
            "data": data,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        dead_connections: List[WebSocket] = []

        async with self._lock:
            connections = list(self.active_connections)

        for connection in connections:
            try:
                await connection.send_json(message)
            except Exception as e:
                logger.warning("Failed to send message to websocket client: %s", e)
                dead_connections.append(connection)

        if dead_connections:
            async with self._lock:
                for dc in dead_connections:
                    if dc in self.active_connections:
                        self.active_connections.remove(dc)


realtime_manager = RealtimeConnectionManager()
