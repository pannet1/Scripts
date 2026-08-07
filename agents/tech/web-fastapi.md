# Tech: FastAPI

- **Framework**: FastAPI only — no Django, Flask, Tornado, Bottle, Pyramid.
- **Validation**: Pydantic v2 `BaseModel` for all schemas. No `dataclasses`, no `TypedDict`.
- **Routes**: `router = APIRouter(prefix=..., tags=[...])` per feature controller.
- **Discovery**: auto-scan `features/` at startup — no manual route registration in `main.py`.
- **Error handling**:
  - Validation errors → 422 (automatic from Pydantic).
  - Business exceptions → custom exceptions in `shared/errors.py`.
  - Unhandled → 500.
  - No try/except in controllers for business logic failures.
- **Auth**: `from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials`.
- **JWT**: `from jose import jwt, JWTError`.
- **Templates**: `from fastapi.templating import Jinja2Templates`.
- **Static**: `from fastapi.staticfiles import StaticFiles`.
- **All handlers are async**.
