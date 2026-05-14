"""
VOCABO — Flask REST API Backend
Cung cấp API cho React frontend
"""
from flask import Flask
from flask_cors import CORS
from config import CORS_ORIGINS, SECRET_KEY, DEBUG, PORT

def create_app() -> Flask:
    app = Flask(__name__)
    app.secret_key = SECRET_KEY

    # ── CORS: cho phép React frontend gọi API ─────────────────────────────────
    CORS(app, origins=CORS_ORIGINS, supports_credentials=True)

    # ── Register blueprints ────────────────────────────────────────────────────
    from api.routes.config_routes    import config_bp
    from api.routes.proxy_routes     import proxy_bp
    from api.routes.ai_routes        import ai_bp
    from api.routes.dictionary_routes import dictionary_bp

    app.register_blueprint(config_bp,       url_prefix="/api")
    app.register_blueprint(proxy_bp,        url_prefix="/api")
    app.register_blueprint(ai_bp,           url_prefix="/api/ai")
    app.register_blueprint(dictionary_bp,   url_prefix="/api")

    # ── Health check ───────────────────────────────────────────────────────────
    @app.route("/health")
    def health():
        return {"status": "ok", "service": "VOCABO API"}, 200

    return app


if __name__ == "__main__":
    app = create_app()
    app.run(debug=DEBUG, host="0.0.0.0", port=PORT)
