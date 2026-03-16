#!/usr/bin/env python3
import json
import requests
from datetime import datetime
import sys
import os
import subprocess
import fcntl
import time
from pathlib import Path

# Add these constants after your existing constants
CACHE_DIR = Path.home() / ".cache" / "waybar"
LOCATION_CACHE = CACHE_DIR / "location.json"
WEATHER_CACHE = CACHE_DIR / "weather.json"
CACHE_DURATION = 3600  # 1 hour in seconds

# Ensure cache directory exists
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Load environment variables from .env file


def get_cached_location():
    """Get cached location data if available and fresh."""
    if not LOCATION_CACHE.exists():
        return None

    try:
        stat = LOCATION_CACHE.stat()
        if time.time() - stat.st_mtime > CACHE_DURATION:
            return None  # Cache expired

        with open(LOCATION_CACHE, "r") as f:
            return json.loads(f.read())
    except (json.JSONDecodeError, OSError):
        return None


def cache_location(location_data):
    """Cache location data to file."""
    try:
        with open(LOCATION_CACHE, "w") as f:
            json.dump(location_data, f)
    except OSError:
        pass  # Ignore cache write failures


def load_env_file():
    """Load environment variables from .env file in parent directory."""
    # Get the directory where this script is located
    script_dir = Path(__file__).parent
    # Look for .env file in parent directory
    env_file = script_dir.parent / ".env"

    if env_file.exists():
        with open(env_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    # Remove quotes if present
                    value = value.strip("\"'")
                    os.environ[key.strip()] = value
    else:
        # Also check current directory as fallback
        env_file = script_dir / ".env"
        if env_file.exists():
            with open(env_file, "r") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, value = line.split("=", 1)
                        value = value.strip("\"'")
                        os.environ[key.strip()] = value


# Load environment variables first
load_env_file()

# WeatherAPI.com API key
WEATHER_API_KEY = os.getenv("WEATHER_API_KEY", "")
if not WEATHER_API_KEY:
    subprocess.run(
        [
            "notify-send",
            "Weather API key not set. Please set WEATHER_API_KEY in waybar/.env file.",
        ]
    )
    sys.exit(1)

# Timeout for API requests (seconds)
TIMEOUT = 10

# Weather condition mapping to icons
WEATHER_CODES = {
    # Clear/Sunny
    "sunny": "☀️",
    "clear": "☀️",
    "fair": "🌤️",
    # Cloudy
    "partly_cloudy": "⛅",
    "mostly_cloudy": "☁️",
    "cloudy": "☁️",
    "overcast": "☁️",
    # Rain
    "light_rain": "🌦️",
    "rain": "🌧️",
    "heavy_rain": "⛈️",
    "showers": "🌦️",
    "thunderstorms": "⛈️",
    "drizzle": "🌦️",
    # Snow
    "light_snow": "🌨️",
    "snow": "❄️",
    "heavy_snow": "🌨️",
    "blizzard": "🌨️",
    # Other
    "fog": "🌫️",
    "mist": "🌫️",
    "haze": "🌫️",
    "windy": "💨",
    # Default
    "unknown": "❓",
}


def get_current_location():
    """Get current location using ip-api.com."""
    # Try cached location first
    cached_location = get_cached_location()
    if cached_location:
        return cached_location
    # Use file locking to prevent multiple instances from fetching simultaneously
    lock_file = CACHE_DIR / "location.lock"
    # File locking code stays the same...
    try:
        with open(lock_file, "w") as lock:
            try:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)

                # Double-check cache after acquiring lock
                cached_location = get_cached_location()
                if cached_location:
                    return cached_location

                # ip-api.com endpoint
                response = requests.get("https://ipwho.is/", timeout=TIMEOUT)
                response.raise_for_status()
                data = response.json()

                if data["success"] != True:
                    raise ValueError(
                        f"API error: {data.get('message', 'Unknown error')}"
                    )

                latitude = float(data["latitude"])
                longitude = float(data["longitude"])
                city = data["city"]
                region = data["region"]  # Different field name
                country = data["country"]

                location_name = f"{city}, {region}"
                if country != "United States":
                    location_name += f", {country}"

                location_data = {
                    "latitude": latitude,
                    "longitude": longitude,
                    "location_name": location_name,
                    "city": city,
                    "region": region,
                    "country": country,
                }

                cache_location(location_data)
                return location_data

            except (
                BlockingIOError
            ):  # Another instance is fetching location, wait and try cache again
                time.sleep(1)
                cached_location = get_cached_location()
                if cached_location:
                    return cached_location

                # If still no cache, return fallback
                return None
            finally:
                try:
                    fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass
                try:
                    lock_file.unlink(missing_ok=True)
                except OSError:
                    pass

    except requests.exceptions.RequestException as e:
        print(f"Error getting location: {e}", file=sys.stderr)
        # Try to return stale cache if available
        if LOCATION_CACHE.exists():
            try:
                with open(LOCATION_CACHE, "r") as f:
                    return json.loads(f.read())
            except (json.JSONDecodeError, OSError):
                pass
        return None
    except (KeyError, ValueError) as e:
        print(f"Error parsing location data: {e}", file=sys.stderr)
        return None


def get_weather_icon(condition):
    """Get weather icon based on condition string."""
    condition_lower = condition.lower()

    # Check for specific conditions
    if any(word in condition_lower for word in ["sunny", "clear"]):
        return WEATHER_CODES["sunny"]
    elif any(word in condition_lower for word in ["partly cloudy", "partly sunny"]):
        return WEATHER_CODES["partly_cloudy"]
    elif any(
        word in condition_lower for word in ["mostly cloudy", "cloudy", "overcast"]
    ):
        return WEATHER_CODES["cloudy"]
    elif any(word in condition_lower for word in ["thunderstorm", "thunder"]):
        return WEATHER_CODES["thunderstorms"]
    elif any(word in condition_lower for word in ["rain", "shower"]):
        return WEATHER_CODES["rain"]
    elif any(word in condition_lower for word in ["drizzle"]):
        return WEATHER_CODES["drizzle"]
    elif any(word in condition_lower for word in ["snow", "blizzard"]):
        return WEATHER_CODES["snow"]
    elif any(word in condition_lower for word in ["fog", "mist", "haze"]):
        return WEATHER_CODES["fog"]
    elif "wind" in condition_lower:
        return WEATHER_CODES["windy"]
    else:
        return WEATHER_CODES["unknown"]


def celsius_to_fahrenheit(celsius):
    """Convert Celsius to Fahrenheit."""
    return round(celsius * 9 / 5 + 32)


def fahrenheit_to_celsius(fahrenheit):
    """Convert Fahrenheit to Celsius."""
    return round((fahrenheit - 32) * 5 / 9)


def get_weatherapi_data(location_data):
    """Get weather data from WeatherAPI.com."""
    if not location_data:
        return None

    try:
        # Use lat,lon for more accurate results
        query = f"{location_data['latitude']},{location_data['longitude']}"

        # WeatherAPI forecast endpoint (includes current + forecast data)
        forecast_url = "https://api.weatherapi.com/v1/forecast.json"
        params = {
            "key": WEATHER_API_KEY,
            "q": query,
            "days": 7,  # Get 7-day forecast
            "aqi": "no",  # Don't need air quality data
            "alerts": "no",  # Don't need weather alerts for this use case
        }

        response = requests.get(forecast_url, params=params, timeout=TIMEOUT)
        response.raise_for_status()
        data = response.json()

        return {
            "location": data["location"],
            "current": data["current"],
            "forecast": data["forecast"],
            "source": "weatherapi",
        }

    except requests.exceptions.RequestException as e:
        print(f"Error fetching WeatherAPI data: {e}", file=sys.stderr)
        return None
    except (KeyError, ValueError) as e:
        print(f"Error parsing WeatherAPI data: {e}", file=sys.stderr)
        return None


def format_weather_data(weather_data, location_data):
    """Format weather data for waybar display."""
    if not weather_data or not location_data:
        return {"text": "❌ N/A", "tooltip": "Weather data unavailable"}

    current = weather_data["current"]
    forecast = weather_data.get("forecast", {})
    forecast_days = forecast.get("forecastday", [])
    location = weather_data.get("location", {})

    # Current temperature and condition
    temp_c = current["temp_c"]
    temp_f = current["temp_f"]
    condition = current["condition"]["text"]
    icon = get_weather_icon(condition)

    # Format current display - using Fahrenheit as primary
    temp_display = f"{int(temp_f)}°F"

    data = {
        "text": f"{icon} {temp_display}",
        "tooltip": f"<b>{condition} {int(temp_f)}°F ({int(temp_c)}°C)</b>\n",
    }

    # Add current details
    data["tooltip"] += (
        f"Location: {location.get('name', 'Unknown')}, {location.get('region', '')}\n"
    )
    data["tooltip"] += (
        f"Feels like: {int(current['feelslike_f'])}°F ({int(current['feelslike_c'])}°C)\n"
    )
    data["tooltip"] += f"Wind: {current['wind_mph']} mph {current['wind_dir']}\n"
    data["tooltip"] += f"Humidity: {current['humidity']}%\n"
    data["tooltip"] += f"UV Index: {current['uv']}\n"

    # Add hourly forecast for today (next 12 hours)
    if forecast_days and len(forecast_days) > 0:
        today_forecast = forecast_days[0]
        hourly_data = today_forecast.get("hour", [])

        # Get current hour and show next 12 hours
        current_time = datetime.now()
        current_hour = current_time.hour

        data["tooltip"] += "\n<b>Hourly Forecast (Next 12 Hours):</b>\n"

        hours_shown = 0
        for hour_data in hourly_data:
            hour_time = datetime.strptime(hour_data["time"], "%Y-%m-%d %H:%M")

            # Skip past hours and current hour, show future hours
            if hour_time.hour <= current_hour:
                continue

            if hours_shown >= 12:
                break

            hour_display = hour_time.strftime("%H:%M")
            hour_temp_f = int(hour_data["temp_f"])
            hour_temp_c = int(hour_data["temp_c"])
            hour_condition = hour_data["condition"]["text"]
            hour_icon = get_weather_icon(hour_condition)
            chance_rain = hour_data.get("chance_of_rain", 0)

            rain_info = f" ({chance_rain}% rain)" if chance_rain > 0 else ""
            data["tooltip"] += (
                f"{hour_display} {hour_icon} {hour_temp_f}°F {hour_condition}{rain_info}\n"
            )
            hours_shown += 1

    # Add daily forecast (next 7 days)
    if forecast_days:
        data["tooltip"] += "\n<b>Daily Forecast:</b>\n"

        for i, day_data in enumerate(forecast_days[:7]):
            day_time = datetime.strptime(day_data["date"], "%Y-%m-%d")

            if i == 0:
                day_name = "Today"
            elif i == 1:
                day_name = "Tomorrow"
            else:
                day_name = day_time.strftime("%A")

            day_info = day_data["day"]
            max_temp_f = int(day_info["maxtemp_f"])
            min_temp_f = int(day_info["mintemp_f"])
            day_condition = day_info["condition"]["text"]
            day_icon = get_weather_icon(day_condition)
            chance_rain = day_info.get("daily_chance_of_rain", 0)

            rain_info = f" ({chance_rain}% rain)" if chance_rain > 0 else ""
            data["tooltip"] += (
                f"{day_name}: {day_icon} {max_temp_f}°/{min_temp_f}°F {day_condition}{rain_info}\n"
            )

    # Add source info
    data["tooltip"] += "\n<i>Data from WeatherAPI.com</i>"

    return data


def main():
    """Main function."""
    try:
        # Get current location
        location_data = get_current_location()
        if not location_data:
            result = {
                "text": "❌ Location",
                "tooltip": "Unable to determine current location",
            }
            print(json.dumps(result))
            return

        # Get weather data from WeatherAPI
        weather_data = get_weatherapi_data(location_data)
        result = format_weather_data(weather_data, location_data)
        print(json.dumps(result))

    except Exception as e:
        # Fallback error output
        error_result = {
            "text": "❌ Error",
            "tooltip": f"Weather service error: {str(e)}",
        }
        print(json.dumps(error_result))


if __name__ == "__main__":
    main()
