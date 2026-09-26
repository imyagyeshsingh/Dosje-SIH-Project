from __future__ import annotations

from decimal import Decimal
from math import atan2, cos, radians, sin, sqrt

DEFAULT_LOCATION_VERIFICATION_RADIUS_METERS = 50.0


def haversine_distance_meters(
    latitude_1: Decimal | float,
    longitude_1: Decimal | float,
    latitude_2: Decimal | float,
    longitude_2: Decimal | float,
) -> float:
    lat1 = float(latitude_1)
    lon1 = float(longitude_1)
    lat2 = float(latitude_2)
    lon2 = float(longitude_2)

    earth_radius_meters = 6371000.0
    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)
    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)

    a = (
        sin(delta_lat / 2) ** 2
        + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon / 2) ** 2
    )
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return earth_radius_meters * c


def verify_location_against_project(
    project_latitude: Decimal | float | None,
    project_longitude: Decimal | float | None,
    inspection_latitude: Decimal | float | None,
    inspection_longitude: Decimal | float | None,
    verification_radius_meters: float = DEFAULT_LOCATION_VERIFICATION_RADIUS_METERS,
) -> tuple[float | None, bool]:
    if (
        project_latitude is None
        or project_longitude is None
        or inspection_latitude is None
        or inspection_longitude is None
    ):
        return None, False

    distance_meters = haversine_distance_meters(
        project_latitude,
        project_longitude,
        inspection_latitude,
        inspection_longitude,
    )
    return distance_meters, distance_meters <= verification_radius_meters
