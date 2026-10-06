"""users ve test_results tablolarını oluşturur

Revision ID: 0001
Revises:
Create Date: 2026-09-26
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Mobil uygulamadaki paket durumlarının karşılığı.
SUBSCRIPTION_VALUES = ("free", "lifetime_tests", "ai_pro")

# Tek bir tip nesnesi: PostgreSQL'de enum tipini `create_table` kendisi
# oluşturur, SQLite'da VARCHAR + CHECK'e dönüşür.
subscription_status = sa.Enum(*SUBSCRIPTION_VALUES, name="subscription_status")


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "subscription_status",
            subscription_status,
            server_default="free",
            nullable=False,
        ),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "test_results",
        sa.Column("id", sa.Integer(), primary_key=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("test_id", sa.Integer(), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column(
            "completed_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_test_results_user_id_users",
            ondelete="CASCADE",
        ),
        sa.CheckConstraint(
            "score >= 0 AND score <= 100",
            name="ck_test_results_score",
        ),
        sa.CheckConstraint("test_id >= 1", name="ck_test_results_test_id"),
    )
    op.create_index("ix_test_results_user_id", "test_results", ["user_id"])
    op.create_index("ix_test_results_completed_at", "test_results", ["completed_at"])
    op.create_index(
        "ix_test_results_user_test",
        "test_results",
        ["user_id", "test_id"],
    )
    op.create_index(
        "ix_test_results_user_completed",
        "test_results",
        ["user_id", "completed_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_test_results_user_completed", table_name="test_results")
    op.drop_index("ix_test_results_user_test", table_name="test_results")
    op.drop_index("ix_test_results_completed_at", table_name="test_results")
    op.drop_index("ix_test_results_user_id", table_name="test_results")
    op.drop_table("test_results")

    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")

    # Tabloyu silmek PostgreSQL'de enum tipini bırakır; elle temizliyoruz.
    subscription_status.drop(op.get_bind(), checkfirst=True)
