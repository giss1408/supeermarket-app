import pytest

from catalog.importers import import_products_csv
from catalog.models import Product
from common.csv_import import CsvImportError
from tests.factories import CategoryFactory

pytestmark = pytest.mark.django_db

HEADER = "retailer_slug,name,category_slug,unit,ean,description\n"


def test_product_csv_import_valid_rows():
    CategoryFactory(slug="fruit")
    CategoryFactory(slug="dairy")
    data = (
        HEADER + "test-retailer,Apple,fruit,1 kg,12345678,Crisp\n"
        "test-retailer,Milk,dairy,1 l,,\n"
        "test-retailer,Pear,fruit,,,\n"
    )
    assert import_products_csv(data) == 3
    assert Product.objects.count() == 3
    assert Product.objects.get(name="Milk").ean is None


def test_product_csv_import_bad_row_imports_nothing():
    CategoryFactory(slug="fruit")
    data = (
        HEADER + "test-retailer,Apple,fruit,1 kg,12345678,\n"
        "test-retailer,Ghost,nope,,,\n"
        "test-retailer,Bad,fruit,,abc,\n"
    )
    with pytest.raises(CsvImportError) as exc:
        import_products_csv(data)
    assert Product.objects.count() == 0
    assert any("Row 3" in e for e in exc.value.errors)
    assert any("Row 4" in e for e in exc.value.errors)


def test_product_csv_duplicate_ean_in_file_imports_nothing():
    CategoryFactory(slug="fruit")
    data = HEADER + "test-retailer,A,fruit,,12345678,\ntest-retailer,B,fruit,,12345678,\n"
    with pytest.raises(CsvImportError) as exc:
        import_products_csv(data)
    assert Product.objects.count() == 0
    assert any("Row 3" in e and "duplicate EAN" in e for e in exc.value.errors)


def test_product_csv_unknown_retailer_imports_nothing():
    CategoryFactory(slug="fruit")
    data = HEADER + "nobody,Apple,fruit,,,\n"
    with pytest.raises(CsvImportError) as exc:
        import_products_csv(data)
    assert any("unknown retailer_slug" in e for e in exc.value.errors)
