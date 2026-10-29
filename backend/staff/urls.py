from rest_framework.routers import SimpleRouter

from .views import CategoryViewSet, FlyerViewSet, OfferViewSet, ProductViewSet, StoreViewSet

router = SimpleRouter(trailing_slash=False)
router.register("flyers", FlyerViewSet, basename="staff-flyer")
router.register("offers", OfferViewSet, basename="staff-offer")
router.register("products", ProductViewSet, basename="staff-product")
router.register("categories", CategoryViewSet, basename="staff-category")
router.register("stores", StoreViewSet, basename="staff-store")

urlpatterns = router.urls
