# Archery Scoring & Target Detection Application

A full-stack, athlete-focused Archery Scoring Application built on FastAPI, MySQL, and Computer Vision. Designed for archery athletes and coaches to track training and tournament rounds with World Archery standard rules, precise statistics, and optional AI target detection.

---

## 🎯 Features

- **Manual Scoring MVP**: Fast, tactile touch-friendly keypad (X, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, M) optimized for quick entry on mobile and desktop at the range.
- **Initial Bow Categories**:
  - `Recurve` (Olympic distance, e.g. 70m)
  - `Compound` (e.g. 50m)
  - `Barebow`
  - `Standard Bow / National`
- **Scoring Engine**:
  - Per-end total, X count, arrow count, and average score calculation.
  - Cumulative session totals, overall average per arrow and per end, highest-scoring end, and lowest-scoring end.
  - Edit support: correct any individual arrow score in real-time.
- **Visual Analytics**:
  - Interactive progression chart displaying cumulative total and per-end score bars.
  - Official end-by-end scorecard breakdown.
- **AI Target & Arrow Detection**:
  - Concentric 10-ring target boundary detection and arrow impact coordinate extraction.
  - Interactive athlete confirmation: AI results are presented as candidate scores for the athlete to review and confirm before saving (`source: 'ai'`). AI results never silently overwrite confirmed scores.
  - Supports Roboflow API models with local OpenCV computer vision fallback.
- **Legacy Compatibility**: Retains existing prototype endpoints (`/api/archer/arrows`, `/api/archer/{range_id}/detect`) and legacy database structures.

---

## 🏛 Architecture

The project follows a clean layered separation of concerns:

```text
Archery-target-detection/
├── routes/                      # FastAPI endpoint declarations
│   ├── scoring_routes.py        # Athletes, Sessions, Ends, and Scoring APIs
│   └── score_detection_routes.py # Legacy prototype detection routes
├── controllers/                 # HTTP request/response orchestration
│   ├── scoring_controller.py
│   └── score_detection_controller.py
├── services/                    # Core business logic and validation
│   ├── scoring_service.py
│   └── score_detection_services.py
├── repositories/                # Database persistence layer (MySQL via aiomysql)
│   ├── athlete_repository.py
│   ├── session_repository.py
│   ├── end_repository.py
│   ├── arrow_repository.py
│   ├── range_repository.py
│   └── arrow_staging_repository.py
├── models/                      # Pydantic schemas and enums
│   └── scoring_models.py
├── ml/                          # Computer vision & target detection pipeline
│   └── target_detector.py
├── utils/                       # Pure mathematical scoring logic
│   └── scoring.py
├── static/                      # Modern Athlete Web UI (HTML5, CSS3, ES6, Chart.js)
│   ├── css/style.css
│   ├── js/app.js
│   └── index.html
├── tests/                       # Automated unit and API integration tests
│   ├── test_scoring.py
│   └── test_api.py
├── database.py                  # Connection pool & automatic schema provisioning
├── schema.sql                   # MySQL relational schema definition
└── main.py                      # FastAPI app entry point & static file server
```

---

## ⚙️ Environment Variables

Copy `.env.example` to `.env` and set your credentials:

```bash
cp .env.example .env
```

| Variable | Default | Description |
| :--- | :--- | :--- |
| `DB_HOST` | `127.0.0.1` | MySQL server host |
| `DB_PORT` | `3306` | MySQL server port |
| `DB_USER` | `root` | MySQL user |
| `DB_PASSWORD` | `123` | MySQL password |
| `DB_NAME` | `archery_scoring_db` | Target database name |
| `UPLOAD_DIR` | `uploads` | Temporary directory for target image analysis |
| `REACT_URL` | `localhost:5173` | Allowed frontend URL for CORS |
| `ROBOFLOW_API` | *(optional)* | Roboflow API key for cloud model inference |

---

## 🚀 Installation & Setup

### 1. Prerequisites
- Python 3.10+
- MySQL Server 8.0+

### 2. Virtual Environment & Dependencies
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pip install pytest httpx python-multipart opencv-python-headless
```

### 3. Database Initialization
Tables are automatically created upon application startup from `schema.sql`. You can also manually provision the database:
```bash
mysql -u root -p < schema.sql
```

### 4. Running the Application
```bash
# Start development server
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

- Open the Web UI: **`http://localhost:8000/`**
- Interactive Swagger API Docs: **`http://localhost:8000/docs`**

---

## 📡 API Endpoints

### Athletes
- `POST /api/athletes` - Register an athlete
- `GET /api/athletes` - List athletes
- `GET /api/athletes/{athlete_id}` - Get athlete details

### Scoring Sessions
- `POST /api/sessions` - Create a new scoring session
- `GET /api/sessions` - List recent sessions
- `GET /api/sessions/{session_id}` - Retrieve full session details, ends, and cumulative stats
- `DELETE /api/sessions/{session_id}` - Delete session
- `PATCH /api/sessions/{session_id}/complete` - Mark session as completed

### Ends & Arrow Scores
- `POST /api/sessions/{session_id}/ends` - Record an end
- `PUT /api/sessions/{session_id}/ends/{end_number}` - Edit an end's arrow scores
- `GET /api/sessions/{session_id}/score` - Retrieve calculated score summary

### AI Detection
- `POST /api/sessions/{session_id}/detect` - Upload target image for computer-vision detection

---

## 📝 Example Requests

### 1. Create a Scoring Session
```http
POST /api/sessions
Content-Type: application/json

{
  "athlete_id": 1,
  "bow_category": "Recurve",
  "session_type": "competition",
  "distance": "70m",
  "arrows_per_end": 6,
  "total_ends": 10
}
```

### 2. Record an End
```http
POST /api/sessions/1/ends
Content-Type: application/json

{
  "end_number": 1,
  "arrows": [
    {"arrow_number": 1, "score": "10X", "is_x": true},
    {"arrow_number": 2, "score": 10, "is_x": false},
    {"arrow_number": 3, "score": 9},
    {"arrow_number": 4, "score": 9},
    {"arrow_number": 5, "score": 8},
    {"arrow_number": 6, "score": 7}
  ]
}
```

**Response (201 Created):**
```json
{
  "id": 1,
  "session_id": 1,
  "end_number": 1,
  "total_score": 53,
  "x_count": 1,
  "arrows": [...]
}
```

---

## 🧪 Testing

Run unit tests and end-to-end integration tests using `pytest`:

```bash
PYTHONPATH=. .venv/bin/pytest -v tests/
```

All 13 automated tests verify:
- Parsing standard scores: `X` (10, is_x=True), `10`..`1`, `M` (0).
- Example calculations: `10X, 10, 9, 8, 7, M` -> Total 44, X 1.
- All X (60 pts, 6 X) and All M (0 pts, 0 X).
- Duplicate arrow detection and boundary constraints.
- Athlete, session, end recording, editing, and completion flow.
- AI target image concentric detection pipeline.

---

## 📄 License
MIT License.
