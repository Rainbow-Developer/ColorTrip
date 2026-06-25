"""공통 응답 Envelope.

규약: docs/conventions/api-design.md — { code, status, message, data }
"""

from pydantic import BaseModel


class Envelope[T](BaseModel):
    code: str
    status: int
    message: str
    data: T | None = None


def success[T](
    data: T | None = None,
    *,
    message: str = "요청이 성공했습니다.",
    status: int = 200,
    code: str = "SUCCESS",
) -> Envelope[T]:
    return Envelope(code=code, status=status, message=message, data=data)
