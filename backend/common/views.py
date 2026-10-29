from rest_framework.permissions import AllowAny
from rest_framework.views import APIView


class PublicReadMixin(APIView):
    """Anonymous, read-only access. No authentication, so a stale Bearer token never 401s.

    Views built on this expose only GET handlers, so other methods yield a standard 405.
    (Adding ``ReadOnly`` here would turn that 405 into a 403, because permissions run first.)
    """

    authentication_classes: list = []
    permission_classes = [AllowAny]
