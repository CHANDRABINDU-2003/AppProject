"""
Community routes — shared by all logged-in roles (farmer, seller, analyst).
Posts, comments, likes. This is the social/Q&A layer of the app.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps import get_current_user
from app.models import Comment, Post, User
from app.schemas import CommentIn, CommentOut, PostIn, PostOut

router = APIRouter(prefix="/community", tags=["community"])


@router.get("/posts", response_model=list[PostOut])
def list_posts(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return db.query(Post).order_by(Post.created_at.desc()).all()


@router.post("/posts", response_model=PostOut, status_code=201)
def create_post(
    payload: PostIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    post = Post(user_id=user.id, **payload.model_dump())
    db.add(post)
    db.commit()
    db.refresh(post)
    return post


@router.post("/posts/{post_id}/like", response_model=PostOut)
def like_post(
    post_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    post.likes = (post.likes or 0) + 1
    db.commit()
    db.refresh(post)
    return post


@router.post("/posts/{post_id}/comments", response_model=CommentOut, status_code=201)
def add_comment(
    post_id: int,
    payload: CommentIn,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    comment = Comment(post_id=post_id, user_id=user.id, comment=payload.comment)
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return comment


@router.delete("/posts/{post_id}", status_code=204)
def delete_post(
    post_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    post = db.query(Post).filter(Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_id != user.id:                 # only the author can delete
        raise HTTPException(status_code=403, detail="Not your post")
    db.delete(post)
    db.commit()
