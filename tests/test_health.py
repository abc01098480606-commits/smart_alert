from fastapi.testclient import TestClient

from smartalert.main import app

client = TestClient(app)


def test_health_check() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "smartalert"}


def test_agent_status_check() -> None:
    response = client.get("/agent/status")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ready",
        "service": "smartalert",
        "agent": "smartalert-agent",
    }
