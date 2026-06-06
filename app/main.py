import os

from fastapi import FastAPI

app = FastAPI(title="ECS Terraform Lab", version="1.0.0")

PROJECT = os.getenv("PROJECT_NAME", "ecs-terraform-lab")
ENVIRONMENT = os.getenv("ENVIRONMENT", "dev")


@app.get("/")
def root():
    return {"message": "Hello from ECS Fargate", "project": PROJECT, "environment": ENVIRONMENT}


@app.get("/health")
def health():
    return {"status": "ok"}
