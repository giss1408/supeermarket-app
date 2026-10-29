import pytest

from common.csv_import import CsvImportError
from stores.importers import import_stores_csv
from stores.models import Store

pytestmark = pytest.mark.django_db

HEADER = "name,address,city,postcode,latitude,longitude,phone\n"


def test_store_csv_import_valid_rows():
    data = HEADER + "A,1 St,Bonn,53111,50.7,7.1,123\nB,2 St,Koeln,50667,50.9,6.9,\n"
    assert import_stores_csv(data) == 2
    assert Store.objects.count() == 2


def test_store_csv_import_bad_row_imports_nothing():
    data = HEADER + "A,1 St,Bonn,53111,50.7,7.1,\nB,2 St,Koeln,50667,95,6.9,\nC,3 St,X,1,abc,1,\n"
    with pytest.raises(CsvImportError) as exc:
        import_stores_csv(data)
    assert Store.objects.count() == 0
    assert any("Row 3" in e for e in exc.value.errors)
    assert any("Row 4" in e for e in exc.value.errors)
