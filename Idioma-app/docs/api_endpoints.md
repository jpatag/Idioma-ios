# Idioma API Endpoints (MVP)

---

## Authentication
> All protected endpoints require the Firebase ID token in the `Authorization` header. The backend verifies this token on every request. No separate login endpoint is needed.

---

## 1. Get Articles

**Endpoint:**  
`GET /articles`

**Description:**  
Fetch a list of region-specific news articles.

**Headers:**  
`Authorization: Bearer <FIREBASE_ID_TOKEN>`

**Query Parameters:**
- `region` (string, optional): Filter by region code (e.g., `us`, `jp`)
- `limit` (int, optional): Number of articles to return (default: 20)
- `offset` (int, optional): For pagination

**Response:**
```json
{
  "articles": [
    {
      "id": "abc123",
      "title": "News headline",
      "region": "us",
      "publishedAt": "2024-06-01T12:00:00Z",
      "summary": "Short summary...",
      "complexity": "B1"
    }
    // ...more articles
  ]
}
```

**Errors:**
- `401 Unauthorized` — Missing or invalid token
- `500 Internal Server Error`

---

## 2. Get Article Detail

**Endpoint:**  
`GET /articles/{id}`

**Description:**  
Fetch the full content of a specific article.

**Headers:**  
`Authorization: Bearer <FIREBASE_ID_TOKEN>`

**Path Parameters:**
- `id` (string): Article ID

**Response:**
```json
{
  "id": "abc123",
  "title": "News headline",
  "region": "us",
  "publishedAt": "2024-06-01T12:00:00Z",
  "content": "Full article text...",
  "complexity": "B1"
}
```

**Errors:**
- `404 Not Found` — Article does not exist
- `401 Unauthorized`
- `500 Internal Server Error`

---

## 3. Simplify Article

**Endpoint:**  
`POST /simplify`

**Description:**  
Simplifies an article's text to a specified reading level using the LLM.

**Headers:**  
`Authorization: Bearer <FIREBASE_ID_TOKEN>`

**Request Body:**
```json
{
  "text": "Original article text",
  "level": "A2" // or "B1", "B2", "C1"
}
```

**Response:**
```json
{
  "simplified": "Simplified article text at requested level"
}
```

**Errors:**
- `400 Bad Request` — Missing or invalid fields
- `401 Unauthorized`
- `500 Internal Server Error`

---

## Example Error Response

```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```
