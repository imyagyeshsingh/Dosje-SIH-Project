# Video Signaling Protocol (Task 10B)

This document describes the WebSocket signaling contract for browser-to-browser WebRTC conferencing in the DoSJE backend.

## WebSocket URL

Use one WebSocket per VideoSession:

- `ws://<host>/ws/video/<video_session.session_id>`
- `wss://<host>/ws/video/<video_session.session_id>`

The session identifier must be the external UUID `VideoSession.session_id`, not the database numeric id.

## Join flow

### Officer

```json
{
  "type": "join",
  "role": "officer"
}
```

### Representative

```json
{
  "type": "join",
  "role": "representative"
}
```

The server validates:
- the session exists
- the role is valid
- no more than two participants are connected
- the same role is not already connected

When the second participant joins, the server may move the VideoSession from `CREATED` to `ACTIVE` using the existing lifecycle rules.

## Join event

When a participant joins, the server sends:

```json
{
  "type": "participant-joined",
  "role": "officer"
}
```

This is sent to the connected participants so the browser can begin the offer/answer flow.

## Offer / Answer / ICE

### Offer

```json
{
  "type": "offer",
  "sdp": "..."
}
```

### Answer

```json
{
  "type": "answer",
  "sdp": "..."
}
```

### ICE candidate

```json
{
  "type": "ice-candidate",
  "candidate": {
    "candidate": "...",
    "sdpMid": "0",
    "sdpMLineIndex": 0
  }
}
```

The server validates only the outer message shape and relays the payload to the other participant.

## Leave / end

### Leave

```json
{
  "type": "leave"
}
```

### End

```json
{
  "type": "end"
}
```

The server notifies the other participant with:

```json
{
  "type": "participant-left",
  "role": "officer"
}
```

A real WebRTC end can be explicit and should not be confused with a temporary network disconnect.

## Error messages

Malformed or unsupported payloads are returned as:

```json
{
  "type": "error",
  "message": "Invalid JSON message"
}
```

Other examples:

```json
{
  "type": "error",
  "message": "Unsupported signaling message type"
}
```

```json
{
  "type": "error",
  "message": "Invalid participant role"
}
```

```json
{
  "type": "error",
  "message": "Participant role is already connected"
}
```

## Inspection → VideoSession contract

The backend maintains a single inspection-to-video-session relationship using `VideoSession.inspection_id`.

### Random inspection flow

1. `POST /inspections/random`
2. `POST /inspections/{inspection_id}/video-session`
3. `GET /inspections/{inspection_id}/video-session`
4. connect to `WS /ws/video/{video_session.session_id}`

### Alert-triggered inspection flow

1. `POST /inspections/from-alert/{alert_id}`
2. `POST /inspections/{inspection_id}/video-session`
3. `GET /inspections/{inspection_id}/video-session`
4. connect to `WS /ws/video/{video_session.session_id}`

### Inspection video session endpoints

- `POST /inspections/{inspection_id}/video-session` → creates the inspection-linked session if none exists; if one already exists, returns it without creating a duplicate
- `GET /inspections/{inspection_id}/video-session` → returns the linked `VideoSessionResponse` or `404`
- `POST /video-sessions` → still works for standalone sessions and validates project/inspection linkage
- `GET /video-sessions/{video_session_id}` → returns the session by numeric id
- `GET /video-sessions/project/{project_id}` → list sessions in a project

## Browser flow

### Officer

1. `getUserMedia()`
2. `new RTCPeerConnection()`
3. add local tracks
4. `createOffer()`
5. `setLocalDescription()`
6. send offer over signaling socket
7. receive answer over signaling socket
8. exchange ICE candidates

### Representative

1. `getUserMedia()`
2. `new RTCPeerConnection()`
3. add local tracks
4. receive offer over signaling socket
5. `setRemoteDescription()`
6. `createAnswer()`
7. `setLocalDescription()`
8. send answer over signaling socket
9. exchange ICE candidates

## Important deployment note

This backend only handles signaling. A successful signaling setup does not guarantee universal WebRTC connectivity in all real-world network conditions.

- STUN may work for many local/dev setups.
- TURN may be required for restrictive NAT/firewall environments.
- The signaling protocol is designed so TURN can be added later without changing the existing message structure.
