pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options.bar.weather.enable
    readonly property int fetchInterval: Math.max(5, (Config.options.bar.weather.fetchInterval || 10)) * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onEnabledChanged: {
        if (root.enabled) {
            startService()
        } else {
            stopService()
        }
    }

    onGpsActiveChanged: {
        if (!root.enabled) return
        if (root.gpsActive) {
            console.info("[WeatherService] Switching to GPS location mode.")
            positionSource.start()
            if (positionSource.position.latitudeValid && positionSource.position.longitudeValid) {
                root.location = {
                    lat: positionSource.position.coordinate.latitude,
                    lon: positionSource.position.coordinate.longitude,
                    valid: true
                }
                root.getData()
            } else {
                positionSource.update()
            }
        } else {
            console.info("[WeatherService] Switching to manual location mode.")
            positionSource.stop()
            root.location = {
                lat: 0,
                lon: 0,
                valid: false
            }
            root.getData()
        }
    }

    onUseUSCSChanged: if (root.enabled) root.getData()
    onCityChanged: if (root.enabled && !root.gpsActive) root.getData()

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property string activeLocationName: data.city ? data.city : (city ? city : (gpsActive ? "GPS" : "Not set"))

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: "",
        wind: "",
        precip: "",
        visib: "",
        press: "",
        temp: "",
        tempFeelsLike: "",
        clouds: "",
        cr: "",
        lastRefresh: ""
    })

    function parseCoordinates(input) {
        if (!input || typeof input !== "string") return null
        const parts = input.split(",").map(s => s.trim())
        if (parts.length === 2) {
            const lat = parseFloat(parts[0])
            const lon = parseFloat(parts[1])
            if (!isNaN(lat) && !isNaN(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
                return { lat, lon }
            }
        }
        return null
    }

    function refineData(data) {
        let temp = {}
        const rainMm = data?.rain?.["1h"] || data?.rain?.["3h"] || 0
        const snowMm = data?.snow?.["1h"] || data?.snow?.["3h"] || 0

        temp.description = data?.weather?.[0]?.description || ""
        const cloudVal = data?.clouds?.all !== undefined ? data.clouds.all : 0
        temp.clouds = cloudVal + "%"
        temp.cr = cloudVal + "%" // Cloud coverage
        temp.humidity = (data?.main?.humidity || 0) + "%"

        const fmt = (unix) => new Date(unix * 1000).toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            second: "2-digit",
            hour12: true
        })

        temp.sunrise = data?.sys?.sunrise ? fmt(data.sys.sunrise) : "0"
        temp.sunset  = data?.sys?.sunset  ? fmt(data.sys.sunset)  : "0"

        temp.windDir = data?.wind?.deg || 0
        temp.wCode = data?.weather?.[0]?.id || 0
        temp.city = data?.name || root.city || "City"
        temp.lat = (data?.coord?.lat !== undefined) ? data.coord.lat : null
        temp.lon = (data?.coord?.lon !== undefined) ? data.coord.lon : null

        if (root.useUSCS) {
            temp.wind = (data?.wind?.speed || 0) + " mph"
            temp.precip = ((rainMm + snowMm) * 0.0394).toFixed(2) + " in"
            temp.visib = ((data?.visibility || 0) / 1609).toFixed(1) + " mi"
            temp.press = (data?.main?.pressure || 0) + " hPa"
            temp.temp = Math.round(data?.main?.temp || 0) + "°F"
            temp.tempFeelsLike = Math.round(data?.main?.feels_like || 0) + "°F"
        } else {
            temp.wind = (data?.wind?.speed || 0) + " m/s"
            temp.precip = (rainMm + snowMm).toFixed(1) + " mm"
            temp.visib = ((data?.visibility || 0) / 1000).toFixed(1) + " km"
            temp.press = (data?.main?.pressure || 0) + " hPa"
            let roundedTemp = Math.round(data?.main?.temp || 0)
            let roundedFeels = Math.round(data?.main?.feels_like || 0)

            temp.temp = roundedTemp + "°C"
            temp.tempFeelsLike = roundedFeels + "°C"
        }

        temp.lastRefresh = DateTime.time + " • " + DateTime.date

        root.data = temp
    }

    function getData() {
        if (!root.enabled) return

        const defaultApiKey = "8b05d62206f459e1d298cbe5844d7d87"
        let apiKey = KeyringStorage.keyringData?.apiKeys?.openweather || defaultApiKey

        if (!apiKey || apiKey === "") {
            console.error("[WeatherService] Missing OpenWeather API key.")
            return
        }

        let units = root.useUSCS ? "imperial" : "metric"
        let url = "https://api.openweathermap.org/data/2.5/weather?"

        if (root.gpsActive && root.location.valid) {
            url += `lat=${root.location.lat}&lon=${root.location.lon}`
        } else {
            const coords = parseCoordinates(root.city)
            if (coords) {
                url += `lat=${coords.lat}&lon=${coords.lon}`
            } else {
                const targetCity = root.city && root.city.trim() !== "" ? root.city.trim() : "Hanoi"
                url += `q=${formatCityName(targetCity)}`
            }
        }

        url += `&units=${units}`
        url += `&appid=${apiKey}`

        let command = `curl -s "${url}"`

        fetcher.command[2] = command
        fetcher.running = true
    }

    function refresh() {
        if (!root.enabled) return
        if (root.gpsActive) {
            positionSource.update()
        }
        root.getData()
    }

    function formatCityName(cityName) {
        return cityName.trim().split(/\s+/).join('+')
    }

    function startService() {
        if (!root.enabled) return
        if (root.gpsActive) {
            console.info("[WeatherService] Starting GPS service.")
            positionSource.start()
            if (positionSource.position.latitudeValid && positionSource.position.longitudeValid) {
                root.location = {
                    lat: positionSource.position.coordinate.latitude,
                    lon: positionSource.position.coordinate.longitude,
                    valid: true
                }
                root.getData()
            } else {
                positionSource.update()
            }
        } else {
            root.getData()
        }
    }

    function stopService() {
        console.info("[WeatherService] Stopping weather service.")
        positionSource.stop()
        pollTimer.stop()
    }

    Component.onCompleted: {
        if (root.enabled) {
            startService()
        }
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0)
                    return

                try {
                    const parsedData = JSON.parse(text)

                    if (parsedData.cod && parsedData.cod !== 200) {
                        console.error("[WeatherService] API error:", parsedData.message)
                        return
                    }

                    root.refineData(parsedData)
                } catch (e) {
                    console.error("[WeatherService] JSON parse error:", e.message)
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval
        active: root.enabled && root.gpsActive

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                root.location = {
                    lat: position.coordinate.latitude,
                    lon: position.coordinate.longitude,
                    valid: true
                }
                root.getData()
            } else {
                root.gpsActive = root.location.valid ? true : false
                console.error("[WeatherService] Failed to get GPS location.")
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop()
                root.location = {
                    lat: 0,
                    lon: 0,
                    valid: false
                }
                root.gpsActive = false
                console.error("[WeatherService] Could not acquire valid GPS backend.")
                if (root.enabled) root.getData()
            }
        }
    }

    Timer {
        id: pollTimer
        running: root.enabled && !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: root.enabled && !root.gpsActive
        onTriggered: root.getData()
    }
}