"""
Applet: Planetarium
Summary: Shows where the planets are
Description: A simulated orrery showing the relative position of the planets around the sun at various points in time. Also functions as a slow-moving clock.
Author: dinosaursrarr
"""

load("math.star", "math")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

START_DATE = time.time(year = 1900, month = 1, day = 1)

# Modes in which it can be used
CLOCK_MODE = "clock"
IMAGE_SET = "image_set"
ANIMATE_NOW = "animate_now"
ANIMATE_SET = "animate_set"

SUN_COLOUR = "#ffff00"

# ith colour used to draw ith planet (Mercury = 0th).
# https://astronomy.stackexchange.com/questions/14032/color-of-planets
COLORS = [
    "#666666",
    "#e6e6e6",
    "#2f6a69",
    "#993d00",
    "#b07f35",
    "#b08f36",
    "#5580aa",
    "#366896",
]

CENTRE_X = 31
CENTRE_Y = 15

# Widgets that are drawn a lot can be reused.
NUMERALS = [
    render.Text(
        str(i),
        font = "tom-thumb",
    )
    for i in range(10)
]

SPACE = render.Text(
    "",
    font = "tom-thumb",
)

THE_SUN = render.Padding(
    pad = (CENTRE_X, CENTRE_Y, 0, 0),
    child = render.Box(
        color = SUN_COLOUR,
        width = 1,
        height = 1,
    ),
)

PLANETS = [
    render.Box(
        color = COLORS[p],
        width = 1,
        height = 1,
    )
    for p in range(8)
]

def digit(number, d):
    return math.floor(number / math.pow(10, d - 1)) % 10

def radius(planet, furthest_planet):
    return (15.0 / furthest_planet) * (planet + 1) + 1

def write_date(date):
    return render.Padding(
        pad = (56, 0, 0, 0),
        child = render.Row(
            children = [
                render.Column(
                    expanded = True,
                    main_align = "center",
                    children = [
                        NUMERALS[digit(date.day, i)]
                        for i in range(2, 0, -1)
                    ] + [
                        SPACE,
                    ] + [
                        NUMERALS[digit(date.month, i)]
                        for i in range(2, 0, -1)
                    ],
                ),
                render.Column(
                    expanded = True,
                    main_align = "center",
                    children = [
                        NUMERALS[digit(date.year, i)]
                        for i in range(4, 0, -1)
                    ],
                ),
            ],
        ),
    )

def draw_date(date, furthest_planet, show_date):
    days_since_start = (date - START_DATE) / (time.hour * 24)
    if days_since_start < 0:
        date = START_DATE
    positions = [position(p, date, furthest_planet) for p in range(furthest_planet)]
    children = [THE_SUN]
    if show_date:
        children = [write_date(date)] + children

    return render.Stack(
        children +
        [
            render.Padding(
                pad = (positions[p][0], positions[p][1], 0, 0),
                child = PLANETS[p],
            )
            for p in range(furthest_planet)
        ],
    )

def main(config):
    default_start = time.now()
    start = config.get("start_date")
    if not start:
        start_date = default_start
    else:
        start_date = time.parse_time(start)
        if start_date < START_DATE:
            start_date = START_DATE

    furthest_planet = int(config.get("furthest_planet", "8"))

    mode = config.get("mode")
    show_date = config.bool("show_date")

    if not mode or mode == CLOCK_MODE:
        return render.Root(
            child = draw_date(time.now(), furthest_planet, show_date),
        )
    if mode == IMAGE_SET:
        start = config.get("start_date")
        if not start:
            start_date = time.now()
        return render.Root(
            child = draw_date(start_date, furthest_planet, show_date),
        )
    if mode == ANIMATE_NOW:
        now = time.now()
        return render.Root(
            delay = 50,
            child = render.Animation(
                children = [draw_date(time.time(year = now.year, month = now.month, day = now.day + d), furthest_planet, show_date) for d in range(366)],
            ),
        )
    if mode == ANIMATE_SET:
        start = config.get("start_date")
        if not start:
            start_date = time.now()
        return render.Root(
            delay = 50,
            child = render.Animation(
                children = [draw_date(time.time(year = start_date.year, month = start_date.month, day = start_date.day + d), furthest_planet, show_date) for d in range(366)],
            ),
        )
    return []

def mode_options(mode):
    if mode in [IMAGE_SET, ANIMATE_SET]:
        return [
            schema.DateTime(
                id = "start_date",
                name = "Start date",
                desc = "Date from which to start the animation",
                icon = "hourglass",
            ),
        ]
    return []

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Dropdown(
                id = "furthest_planet",
                name = "Furthest planet",
                desc = "Furthest planet from the sun to draw",
                icon = "moon",
                options = [
                    schema.Option(display = "Neptune", value = "8"),
                    schema.Option(display = "Uranus", value = "7"),
                    schema.Option(display = "Saturn", value = "6"),
                    schema.Option(display = "Jupiter", value = "5"),
                    schema.Option(display = "Mars", value = "4"),
                    schema.Option(display = "Earth", value = "3"),
                    schema.Option(display = "Venus", value = "2"),
                    schema.Option(display = "Mercury", value = "1"),
                ],
                default = "8",
            ),
            schema.Dropdown(
                id = "mode",
                name = "Mode",
                desc = "How should results be displayed?",
                icon = "gear",
                options = [
                    schema.Option(display = "Clock", value = CLOCK_MODE),
                    schema.Option(display = "Image of set time", value = IMAGE_SET),
                    schema.Option(display = "Animate from now", value = ANIMATE_NOW),
                    schema.Option(display = "Animate from set time", value = ANIMATE_SET),
                ],
                default = CLOCK_MODE,
            ),
            schema.Generated(
                id = "mode_options",
                source = "mode",
                handler = mode_options,
            ),
            schema.Toggle(
                id = "show_date",
                name = "Show date",
                desc = "Whether to draw the date",
                icon = "clock",
                default = True,
            ),
        ],
    )

def calculate_planet_angle(planet_index, days_since_start):
    # Orbital periods in Earth days
    orbital_periods = [88, 225, 365.25, 687, 4333, 10759, 30687, 60190]
    
    # Orbital eccentricities (affects non-circular motion)
    eccentricities = [0.2056, 0.0068, 0.0167, 0.0934, 0.0489, 0.0565, 0.0457, 0.0113]
    
    # Initial angles on January 1, 1900 (extracted from first element of each ANGLES sublist)
    initial_angles = [-1.96833, 1.25081, -0.16076, 0.4158, -1.73827, -1.89529, 1.23667, -1.29464]
    
    period = orbital_periods[planet_index]
    ecc = eccentricities[planet_index]
    
    # Mean anomaly (position in orbit assuming circular motion)
    mean_anomaly = (days_since_start * 2 * math.pi / period)
    
    # Apply Kepler's equation approximation to account for elliptical orbits
    # E ≈ M + e*sin(M) where E is eccentric anomaly and M is mean anomaly
    eccentric_anomaly = mean_anomaly + ecc * math.sin(mean_anomaly)
    
    # Convert to true anomaly (actual angle in orbit)
    true_anomaly = eccentric_anomaly + 2 * ecc * math.sin(eccentric_anomaly)
    
    # Calculate final angle (initial position + orbital progress)
    angle = initial_angles[planet_index] + true_anomaly
    
    # Normalize to range [-π, π]
    angle = angle % (2 * math.pi)
    if angle > math.pi:
        angle -= 2 * math.pi
        
    return angle

def position(planet, date, furthest_planet):
    days = (date - START_DATE) // (time.hour * 24)
    
    # Use formula instead of lookup
    angle = calculate_planet_angle(planet, days) - (math.pi / 2.0)
    
    # Rest is unchanged
    r = radius(planet, furthest_planet)
    x = int(r * math.cos(angle))
    y = int(r * math.sin(angle))
    return CENTRE_X + x, CENTRE_Y + y

