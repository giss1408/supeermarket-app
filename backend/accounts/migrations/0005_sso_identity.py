from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0004_user_retailer_role_constraint"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="auth_user_id",
            field=models.UUIDField(blank=True, editable=False, null=True, unique=True),
        ),
        migrations.AlterField(
            model_name="user",
            name="email",
            field=models.EmailField(blank=True, max_length=254, null=True, unique=True),
        ),
        migrations.CreateModel(
            name="AuthErasure",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("auth_user_id", models.UUIDField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("attempts", models.PositiveIntegerField(default=1)),
                ("next_attempt_at", models.DateTimeField(db_index=True)),
                ("status", models.CharField(default="pending", max_length=10)),
                ("finished_at", models.DateTimeField(blank=True, null=True)),
            ],
        ),
    ]
