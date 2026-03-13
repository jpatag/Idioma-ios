# Idioma API Endpoints (MVP)

---

## Authentication
> All protected endpoints require the Firebase ID token in the `Authorization` header. The backend verifies this token on every request. No separate login endpoint is needed.

---

## 1. Get Articles

**Endpoint:**  
`GET /getNews`

**Description:**  
Fetch news articles filtered by country, language, and optionally by Idioma interest categories.  
When categories are provided, strong-mapping categories are combined into one NewsData query, while lossy categories (Weather & Disaster, Social Issues & Society, History & Religion) are fetched separately with keyword augmentation and then merged into a balanced feed.

**Headers:**  
`Authorization: Bearer <FIREBASE_ID_TOKEN>` *(currently disabled)*

**Query Parameters:**
- `country` (string, **required**): Country code (e.g., `es`, `fr`, `de`)
- `language` (string, **required**): Language code (e.g., `es`, `fr`, `de`)
- `categories` (string, optional): Comma-separated Idioma category ids (1–14), max 5. Example: `1,4,11`

**Response:**
```json
{
  "results": [
    {
      "article_id": "abc123",
      "title": "News headline",
      "link": "https://...",
      "description": "Short summary...",
      "pubDate": "2024-06-01 12:00:00",
      "image_url": "https://...",
      "source_name": "Example News",
      "language": "spanish",
      "country": ["es"],
      "category": ["politics"],
      "idiomaCategoryIds": [1]
    }
  ]
}
```

**Category ID reference (1–14):**
| ID | Category | NewsData Mapping | Lossy? |
|----|----------|-----------------|--------|
| 1 | Politics & Government | politics | No |
| 2 | Economy & Finance | business | No |
| 3 | Arts & Entertainment | entertainment | No |
| 4 | Sports | sports | No |
| 5 | Business & Labor | business | No |
| 6 | Science & Tech | technology | No |
| 7 | Education | education | No |
| 8 | Crime, Law & Justice | crime | No |
| 9 | History & Religion | other | Yes |
| 10 | Environment & Nature | environment | No |
| 11 | Health & Wellness | health | No |
| 12 | Social Issues & Society | domestic | Yes |
| 13 | Lifestyle & Travel | lifestyle | No |
| 14 | Weather & Disaster | breaking | Yes |

**Cache behavior:**  
Cached 24 hours in Firestore `articles` collection, keyed by `country + language + categoriesKey`.  
Requests with different category sets get separate cache entries.

**Errors:**
- `400`: Missing country/language, invalid category ids, or more than 5 categories
- `500`: API key not configured or fetch failed

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
