class DuplicatePayment(Exception):
    """A payment with the same (provider, reference) was already recorded."""


class SubscriptionRequired(Exception):
    """The retailer has no active, paid subscription."""
