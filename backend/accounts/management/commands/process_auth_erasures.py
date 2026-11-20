import json

from django.core.management.base import BaseCommand

from accounts import erasures


class Command(BaseCommand):
    help = "Retry telling the auth service about people this product erased while it was unreachable (run every 10 minutes). Prints counts only."

    def handle(self, *args, **options):  # type: ignore[no-untyped-def]
        self.stdout.write(json.dumps(erasures.process()))
