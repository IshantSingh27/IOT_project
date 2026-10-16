import os
import shutil
from typing import List
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AuthorizedPerson
from app.schemas import AuthorizedPersonResponse
from app.config import settings
from app.services.face_recognition_service import face_service

router = APIRouter(prefix="/faces", tags=["Face Recognition & Authorized Persons"])

@router.get("", response_model=List[AuthorizedPersonResponse])
def get_authorized_persons(db: Session = Depends(get_db)):
    return db.query(AuthorizedPerson).all()

@router.post("", response_model=AuthorizedPersonResponse)
async def register_face(
    name: str = Form(...),
    relationship: str = Form("Family"),
    photo: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    clean_name = name.strip()
    existing = db.query(AuthorizedPerson).filter(AuthorizedPerson.name == clean_name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Person with this name already exists")

    # Save photo to static/known_faces
    ext = Path(photo.filename).suffix or ".jpg"
    filename = f"{clean_name.lower().replace(' ', '_')}{ext}"
    dest_path = settings.KNOWN_FACES_DIR / filename

    with open(dest_path, "wb") as buffer:
        shutil.copyfileobj(photo.file, buffer)

    # Save to DB
    person = AuthorizedPerson(
        name=clean_name,
        relationship=relationship,
        photo_filename=filename,
        is_active=True
    )
    db.add(person)
    db.commit()
    db.refresh(person)

    # Reload facial recognition encodings in background
    face_service.reload_known_faces()

    return person

@router.delete("/{person_id}")
def delete_person(person_id: int, db: Session = Depends(get_db)):
    person = db.query(AuthorizedPerson).filter(AuthorizedPerson.id == person_id).first()
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")

    if person.photo_filename:
        photo_path = settings.KNOWN_FACES_DIR / person.photo_filename
        if photo_path.exists():
            try:
                os.remove(photo_path)
            except Exception:
                pass

    db.delete(person)
    db.commit()
    face_service.reload_known_faces()
    return {"status": "ok", "message": "Person deleted successfully"}
