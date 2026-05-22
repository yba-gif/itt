"""Import all models so SQLAlchemy registers them with Base.metadata."""

from app.models.ai_question import AIQuestion
from app.models.category import Category
from app.models.consulate import Consulate
from app.models.content_page import ContentPage
from app.models.device_token import DeviceToken
from app.models.event import Event
from app.models.favorite import Favorite
from app.models.invoice import Invoice
from app.models.kanton import Kanton
from app.models.listing import Listing, ListingStatus
from app.models.report import Report
from app.models.saved_search import SavedSearch
from app.models.social import Social
from app.models.user import User

__all__ = [
    "AIQuestion",
    "Category",
    "Consulate",
    "ContentPage",
    "DeviceToken",
    "Event",
    "Favorite",
    "Invoice",
    "Kanton",
    "Listing",
    "ListingStatus",
    "Report",
    "SavedSearch",
    "Social",
    "User",
]
