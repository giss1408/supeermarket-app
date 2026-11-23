import uuid

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from accounts.models import User
from retailers.models import Retailer


class Command(BaseCommand):
    help = (
        "Links a person who exists in the auth service to a staff profile here (a platform admin,"
        " or a retailer's staff member). Staff are never created from a token. The person must "
        "already have the role at auth (platform admins: created by an auth super admin with an "
        "authenticator; retailer staff are enrolled by the platform dashboard, which links them "
        "itself)."
    )

    def add_arguments(self, parser):  # type: ignore[no-untyped-def]
        parser.add_argument("--auth-user-id", required=True)
        parser.add_argument(
            "--role", choices=[User.Role.PLATFORM_ADMIN, User.Role.RETAILER_STAFF], required=True
        )
        parser.add_argument("--name", default="")
        parser.add_argument("--retailer", help="retailer slug (retailer_staff only)")

    def handle(self, *args, **opts):  # type: ignore[no-untyped-def]
        try:
            auth_id = uuid.UUID(opts["auth_user_id"])
        except ValueError:
            raise CommandError("--auth-user-id must be a UUID") from None
        role, retailer = opts["role"], None
        if role == User.Role.RETAILER_STAFF:
            retailer = Retailer.objects.filter(slug=opts["retailer"] or "").first()
            if retailer is None:
                raise CommandError(
                    "--retailer must be an existing retailer slug for a retailer_staff"
                )
        elif opts["retailer"]:
            raise CommandError("a platform_admin belongs to no retailer")
        with transaction.atomic():
            user = User.objects.filter(auth_user_id=auth_id).first()
            if user is not None:
                if user.role != role or user.retailer != retailer:
                    raise CommandError(
                        f"already linked as {user.role}; refusing to change a role silently"
                    )
                self.stdout.write("already linked")
                return
            user = User(
                auth_user_id=auth_id,
                name=opts["name"],
                role=role,
                retailer=retailer,
                is_staff=False,
            )
            user.set_unusable_password()
            user.save()
        self.stdout.write(f"linked {auth_id} as {role}")
