from django.contrib import messages
from django.contrib.auth import get_user_model
from django.contrib.auth.views import LoginView, LogoutView
from django.http import HttpRequest, HttpResponse
from django.shortcuts import get_object_or_404, redirect
from django.urls import reverse
from django.views import View
from django.views.generic import DetailView, FormView, ListView

from retailers.models import Retailer
from retailers.services import set_status

from .forms import PaymentForm, PlatformLoginForm, RetailerCreateForm
from .mixins import PlatformAdminRequiredMixin


class PlatformLoginView(LoginView):
    template_name = "platform_admin/login.html"
    authentication_form = PlatformLoginForm
    redirect_authenticated_user = False

    def get_default_redirect_url(self) -> str:
        return reverse("platform:retailer_list")


class PlatformLogoutView(LogoutView):
    next_page = "platform:login"


FILTERS = ("active", "pending", "expiring", "lapsed")


class RetailerListView(PlatformAdminRequiredMixin, ListView):
    template_name = "platform_admin/retailer_list.html"
    context_object_name = "retailers"

    def get_filter(self) -> str:
        value = self.request.GET.get("filter", "")
        return value if value in FILTERS else ""

    def get_queryset(self):  # type: ignore[no-untyped-def]
        qs = Retailer.objects.select_related("subscription")
        match self.get_filter():
            case "active":
                qs = qs.filter(status=Retailer.Status.ACTIVE)
            case "pending":
                qs = qs.filter(status=Retailer.Status.PENDING)
            case "expiring":
                qs = qs.expiring()
            case "lapsed":
                qs = qs.lapsed()
        return qs

    def get_context_data(self, **kwargs):  # type: ignore[no-untyped-def]
        ctx = super().get_context_data(**kwargs)
        ctx["current_filter"] = self.get_filter()
        ctx["filters"] = [
            ("", "Tous"),
            ("active", "Actifs"),
            ("pending", "En attente"),
            ("expiring", "Expirent bientôt"),
            ("lapsed", "Abonnement expiré"),
        ]
        return ctx


class RetailerCreateView(PlatformAdminRequiredMixin, FormView):
    template_name = "platform_admin/retailer_form.html"
    form_class = RetailerCreateForm

    def form_valid(self, form: RetailerCreateForm) -> HttpResponse:  # type: ignore[override]
        retailer = form.save()
        messages.success(self.request, "Commerçant créé (en attente d'activation).")
        return redirect("platform:retailer_detail", pk=retailer.pk)


class RetailerDetailView(PlatformAdminRequiredMixin, DetailView):
    template_name = "platform_admin/retailer_detail.html"
    queryset = Retailer.objects.select_related("subscription")
    context_object_name = "retailer"

    def get_context_data(self, **kwargs):  # type: ignore[no-untyped-def]
        ctx = super().get_context_data(**kwargs)
        retailer = self.object
        ctx["payments"] = retailer.payments.order_by("-confirmed_at", "-id")
        ctx["staff_users"] = get_user_model().objects.filter(retailer=retailer).order_by("email")
        ctx["subscription"] = getattr(retailer, "subscription", None)
        return ctx


class PaymentCreateView(PlatformAdminRequiredMixin, FormView):
    template_name = "platform_admin/payment_form.html"
    form_class = PaymentForm

    def dispatch(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        # Check access before touching the database for the retailer.
        self.retailer = None
        return super().dispatch(request, *args, **kwargs)

    def get_retailer(self) -> Retailer:
        if self.retailer is None:
            self.retailer = get_object_or_404(Retailer, pk=self.kwargs["pk"])
        return self.retailer

    def get_form_kwargs(self):  # type: ignore[no-untyped-def]
        kwargs = super().get_form_kwargs()
        kwargs.update(retailer=self.get_retailer(), confirmed_by=self.request.user)
        return kwargs

    def get_context_data(self, **kwargs):  # type: ignore[no-untyped-def]
        ctx = super().get_context_data(**kwargs)
        ctx["retailer"] = self.get_retailer()
        return ctx

    def form_valid(self, form: PaymentForm) -> HttpResponse:  # type: ignore[override]
        if form.save() is None:
            return self.form_invalid(form)
        messages.success(self.request, "Paiement enregistré, abonnement prolongé.")
        return redirect("platform:retailer_detail", pk=self.get_retailer().pk)


class _StatusChangeView(PlatformAdminRequiredMixin, View):
    http_method_names = ["post"]
    target = Retailer.Status.ACTIVE
    already = ""
    done = ""

    def post(self, request: HttpRequest, pk: int) -> HttpResponse:
        retailer = get_object_or_404(Retailer, pk=pk)
        if retailer.status == self.target:
            messages.info(request, self.already)
        else:
            set_status(retailer, self.target, by=request.user)  # type: ignore[arg-type]
            messages.success(request, self.done)
        return redirect("platform:retailer_detail", pk=retailer.pk)


class RetailerActivateView(_StatusChangeView):
    target = Retailer.Status.ACTIVE
    already = "Ce commerçant est déjà actif."
    done = "Commerçant activé."


class RetailerSuspendView(_StatusChangeView):
    target = Retailer.Status.SUSPENDED
    already = "Ce commerçant est déjà suspendu."
    done = "Commerçant suspendu."
