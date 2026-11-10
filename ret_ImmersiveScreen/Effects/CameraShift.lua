local _, ns = ...

ns.RegisterModule({
    key = "CameraShift",
    category = "Effects",
    title = "CameraShift",
    description = "Moves the camera to the side, so your character stands off the centre of the frame.",
    placeholder = true,
    lens = true,
    settings = {
        {
            key = "offset",
            type = "slider",
            title = "Camera offset",
            description = "How far the camera moves to the side. Negative values move it the other way.",
            min = -15,
            max = 15,
            step = 0.5,
            default = 1,
            format = "%.1f",
        },
    },
})
