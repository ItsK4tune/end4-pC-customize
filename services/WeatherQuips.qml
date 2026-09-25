pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Singleton {
    id: root

    property int quipIndex: 0
    property var currentQuip: computeQuip()

    readonly property bool isVietnamese: {
        const lang = Config.options.language?.ui || "auto"
        if (lang === "vi_VN" || lang.startsWith("vi")) return true
        if (lang === "auto") {
            const loc = Qt.locale().name
            return loc.startsWith("vi")
        }
        return true // Default friendly Vietnamese support
    }

    Connections {
        target: Weather
        function onDataChanged() {
            root.currentQuip = root.computeQuip()
        }
        function onEnabledChanged() {
            root.currentQuip = root.computeQuip()
        }
    }

    Connections {
        target: DateTime
        function onTimeChanged() {
            // Periodically re-evaluate every 15 minutes or when hour changes
            if (DateTime.minute % 15 === 0) {
                root.currentQuip = root.computeQuip()
            }
        }
    }

    function shuffle() {
        quipIndex++
        currentQuip = computeQuip()
    }

    function computeQuip() {
        const pool = getQuipPool()
        if (!pool || pool.length === 0) {
            return { text: "• have a productive day ahead", icon: "favorite" }
        }
        const idx = Math.abs(quipIndex) % pool.length
        return pool[idx]
    }

    function getQuipPool() {
        const vi = root.isVietnamese
        const hour = DateTime.hour24

        // If weather service is disabled
        if (!Weather.enabled) {
            if (hour >= 23 || hour < 5) {
                return vi ? [
                    { text: "• Đêm đã về khuya, nghỉ ngơi sớm giữ sức khỏe nhé", icon: "bedtime" },
                    { text: "• Chúc bạn một giấc ngủ an lành sau ngày dài", icon: "nightlight" }
                ] : [
                    { text: "• it's late at night, get some rest", icon: "bedtime" },
                    { text: "• sweet dreams and peaceful rest", icon: "nightlight" }
                ]
            }
            if (hour < 9) {
                return vi ? [
                    { text: "• Chào buổi sáng! Nạp năng lượng cho ngày mới nào", icon: "wb_sunny" },
                    { text: "• Khởi đầu ngày mới với nụ cười và sự tập trung", icon: "local_cafe" }
                ] : [
                    { text: "• good morning! ready to seize the day", icon: "wb_sunny" },
                    { text: "• start the day with focus and energy", icon: "local_cafe" }
                ]
            }
            return vi ? [
                { text: "• Tập trung cao độ, hoàn thành từng mục tiêu", icon: "code" },
                { text: "• Học hỏi mỗi ngày để tiến bộ hơn", icon: "school" },
                { text: "• Tận hưởng từng khoảnh khắc làm việc", icon: "favorite" }
            ] : [
                { text: "• stay focused and keep building", icon: "code" },
                { text: "• small progress every day adds up", icon: "trending_up" },
                { text: "• enjoy every creative moment", icon: "favorite" }
            ]
        }

        const desc = (Weather.data?.description ?? "").toLowerCase()
        const tempNum = parseInt(Weather.data?.temp) || 25
        const feelsNum = parseInt(Weather.data?.tempFeelsLike) || tempNum
        const isNight = hour < 6 || hour >= 19

        // 1. Extreme Temperature Check
        if (feelsNum >= 36) {
            return vi ? [
                { text: `• Trời oi bức (${Weather.data?.temp}), nhớ uống nhiều nước nhé`, icon: "local_drink" },
                { text: "• Nắng nóng đỉnh điểm, hạn chế ra đường kẻo say nắng", icon: "thermostat" },
                { text: "• Giữ cho không gian mát mẻ và bổ sung điện giải", icon: "water_drop" }
            ] : [
                { text: `• scorching hot (${Weather.data?.temp}), stay well hydrated`, icon: "local_drink" },
                { text: "• peak heat today, stay in the cool shade", icon: "thermostat" }
            ]
        }

        if (tempNum <= 15 && tempNum > 0) {
            return vi ? [
                { text: `• Trời se lạnh (${Weather.data?.temp}), nhớ giữ ấm cổ và tay nhé`, icon: "ac_unit" },
                { text: "• Gió lạnh ùa về, một ly trà ấm sẽ rất tuyệt", icon: "coffee" },
                { text: "• Thời tiết mát lạnh, mặc thêm áo ấm khi ra ngoài", icon: "dry_cleaning" }
            ] : [
                { text: `• chilly outside (${Weather.data?.temp}), keep yourself warm`, icon: "ac_unit" },
                { text: "• cool crisp air, perfect for a hot tea", icon: "coffee" }
            ]
        }

        // 2. Thunderstorm / Storm
        if (desc.includes("thunder") || desc.includes("storm") || desc.includes("lightning")) {
            return vi ? [
                { text: "• Sấm sét bên ngoài, ở trong nhà là an yên nhất", icon: "bolt" },
                { text: "• Mưa to gió lớn, đường về trơn trượt nhớ đi cẩn thận", icon: "shield" },
                { text: "• Tiếng sấm rền vang và những dòng code mượt mà", icon: "code" }
            ] : [
                { text: "• stormy weather outside, stay safe indoors", icon: "bolt" },
                { text: "• lightning and thunder, perfect excuse to stay in", icon: "thunderstorm" },
                { text: "• cozy indoors with rain thundering outside", icon: "shield" }
            ]
        }

        // 3. Rain / Drizzle / Shower
        if (desc.includes("rain") || desc.includes("drizzle") || desc.includes("shower")) {
            if (desc.includes("light") || desc.includes("patchy")) {
                return vi ? [
                    { text: "• Mưa rào lất phất, nhâm nhi tách cà phê ấm nhé", icon: "coffee" },
                    { text: "• Mưa bóng mây ghé qua, ra ngoài nhớ mang theo ô", icon: "umbrella" },
                    { text: "• Tiếng mưa tí tách, góc làm việc thêm phần thi vị", icon: "water_drop" },
                    { text: "• Một chút mưa nhẹ làm dịu đi cái nóng ban trưa", icon: "water" }
                ] : [
                    { text: "• light rain outside, perfect time for a warm coffee", icon: "coffee" },
                    { text: "• passing shower, keep an umbrella handy", icon: "umbrella" },
                    { text: "• gentle raindrops outside, take it easy today", icon: "water_drop" }
                ]
            }

            return vi ? [
                { text: "• Trời đang mưa, thưởng thức một tách cà phê thơm", icon: "coffee" },
                { text: "• Mưa rơi ngoài hiên, một ngày lắng đọng và bình yên", icon: "umbrella" },
                { text: "• Tiếng mưa rào, tập trung hoàn thiện dự án thôi nào", icon: "code" }
            ] : [
                { text: "• raining outside, grab a cup of hot coffee", icon: "coffee" },
                { text: "• rainy day vibes, calm mind and deep focus", icon: "umbrella" }
            ]
        }

        // 4. Mist / Fog / Haze
        if (desc.includes("mist") || desc.includes("fog") || desc.includes("haze")) {
            return vi ? [
                { text: "• Màn sương bồng bềnh, thành phố như chậm lại một nhịp", icon: "foggy" },
                { text: "• Bầu trời mờ sương, bật một bản Lo-fi nghe thôi nào", icon: "headphones" },
                { text: "• Sương khói mờ ảo, lái xe nhớ bật đèn và đi chậm nhé", icon: "visibility" }
            ] : [
                { text: "• misty atmosphere, city moves in slow motion", icon: "foggy" },
                { text: "• foggy vibes outside, great time for chill music", icon: "headphones" }
            ]
        }

        // 5. Clear / Sunny
        if (desc.includes("clear") || desc.includes("sun")) {
            if (isNight) {
                return vi ? [
                    { text: "• Đêm quang đãng, ngàn vì sao lấp lánh trên cao", icon: "nightlight" },
                    { text: "• Đêm thanh tĩnh, gác lại âu lo chuẩn bị nghỉ ngơi", icon: "bedtime" },
                    { text: "• Bầu trời đêm trong veo, chúc bạn giấc ngủ ngon", icon: "star" }
                ] : [
                    { text: "• clear starlit night, quiet time to unwind", icon: "nightlight" },
                    { text: "• peaceful night sky, rest well and recharge", icon: "bedtime" }
                ]
            }

            if (hour < 10) {
                return vi ? [
                    { text: "• Nắng sớm chan hòa, ngày mới ngập tràn hứng khởi", icon: "wb_twilight" },
                    { text: "• Ánh nắng ban mai tiếp thêm năng lượng cho bạn", icon: "flare" }
                ] : [
                    { text: "• crisp morning sunshine, ready for a productive day", icon: "wb_twilight" },
                    { text: "• morning glow is up, make the most of today", icon: "wb_sunny" }
                ]
            }

            if (hour >= 17) {
                return vi ? [
                    { text: "• Hoàng hôn tuyệt đẹp, buông bỏ áp lực sau ngày dài", icon: "wb_twilight" },
                    { text: "• Nắng chiều dần buông, chuẩn bị cho buổi tối thư giãn", icon: "nightlight" }
                ] : [
                    { text: "• golden hour sunshine, wrap up work and relax", icon: "wb_twilight" }
                ]
            }

            return vi ? [
                { text: "• Trời trong xanh rạng rỡ, ra ngoài hít thở chút khí trời nào", icon: "nature_people" },
                { text: "• Nắng ấm chan hòa, thời điểm tuyệt vời để bứt phá", icon: "wb_sunny" },
                { text: "• Một ngày đẹp trời để theo đuổi những điều bạn yêu thích", icon: "flare" }
            ] : [
                { text: "• bright sunny day, perfect time to touch grass", icon: "nature_people" },
                { text: "• beautiful clear sky, soaking up the sunshine", icon: "wb_sunny" },
                { text: "• wonderful day to make big things happen", icon: "flare" }
            ]
        }

        // 6. Clouds / Overcast / Broken / Scattered
        if (desc.includes("cloud")) {
            if (desc.includes("few") || desc.includes("scattered") || desc.includes("partly")) {
                return vi ? [
                    { text: "• Trời râm mát dịu dàng, thời tiết thật dễ chịu", icon: "cloud" },
                    { text: "• Nắng nhẹ xen kẽ bóng mây, gió thoảng thảnh thơi", icon: "air" },
                    { text: "• Thời tiết lý tưởng, năng lượng dồi dào để làm việc", icon: "filter_drama" }
                ] : [
                    { text: "• pleasant scattered clouds, gentle breeze all around", icon: "cloud" },
                    { text: "• mild and breezy, perfect weather for productivity", icon: "air" }
                ]
            }

            return vi ? [
                { text: "• Mây trôi lững lờ trên phố, lòng người nhẹ nhõm", icon: "cloud" },
                { text: "• Bầu trời êm ả, thời tiết rất thích hợp để tập trung", icon: "filter_drama" },
                { text: "• Mây che bóng mát, một ngày yên bình trôi qua", icon: "cloud_queue" }
            ] : [
                { text: "• a bit cloudy today, peaceful and easy-going", icon: "cloud" },
                { text: "• cool overcast sky, calm mind for deep work", icon: "filter_drama" }
            ]
        }

        // 7. Snow
        if (desc.includes("snow")) {
            return vi ? [
                { text: "• Tuyết rơi lãng mạn, giữ ấm bên ly trà nóng nhé", icon: "ac_unit" },
                { text: "• Mùa đông trắng xóa, tận hưởng sự ấm áp trong nhà", icon: "severe_cold" }
            ] : [
                { text: "• snowing outside, keep warm and stay cozy", icon: "ac_unit" },
                { text: "• winter wonderland, enjoy a hot cocoa indoors", icon: "ac_unit" }
            ]
        }

        // Fallback with description
        const descCap = desc ? (desc.charAt(0).toUpperCase() + desc.slice(1)) : (vi ? "Thời tiết dễ chịu" : "Mild weather")
        return vi ? [
            { text: `• ${descCap} (${Weather.data?.temp || "--"})`, icon: "thermostat" },
            { text: "• Chúc bạn một ngày làm việc hiệu quả và tràn đầy niềm vui", icon: "favorite" }
        ] : [
            { text: `• ${descCap} (${Weather.data?.temp || "--"})`, icon: "thermostat" },
            { text: "• have a wonderful and productive day", icon: "favorite" }
        ]
    }
}
