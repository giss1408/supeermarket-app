from rest_framework.pagination import CursorPagination


class DefaultCursorPagination(CursorPagination):
    """Cursor pagination, 20 per page, newest first.

    Orders by ``-created_at``. Views whose model has no ``created_at`` field MUST
    override ``ordering`` by setting an ``ordering`` attribute on the view
    (e.g. ``ordering = "-id"``); it takes precedence over the default here.
    """

    page_size = 20
    ordering = "-created_at"

    def get_ordering(self, request, queryset, view):  # type: ignore[no-untyped-def]
        view_ordering = getattr(view, "ordering", None)
        if view_ordering:
            self.ordering = view_ordering
        return super().get_ordering(request, queryset, view)
