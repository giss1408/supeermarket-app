import pytest
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse

from stores.models import Store
from tests.factories import default_retailer

pytestmark = pytest.mark.django_db


def test_admin_csv_import_view_and_changelist(client):
    default_retailer()
    admin = get_user_model().objects.create_superuser(email="a@example.com", password="pw12345!x")
    client.force_login(admin)
    assert "Import CSV" in client.get(reverse("admin:stores_store_changelist")).content.decode()
    url = reverse("admin:stores_store_import_csv")
    assert client.get(url).status_code == 200
    csv = (
        "retailer_slug,name,address,city,postcode,latitude,longitude,phone\n"
        "test-retailer,A,1 St,Bonn,53111,50.7,7.1,\n"
    )
    resp = client.post(url, {"file": SimpleUploadedFile("s.csv", csv.encode())})
    assert resp.status_code == 302
    assert Store.objects.count() == 1
