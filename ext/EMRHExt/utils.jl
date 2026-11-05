function Accessors.ConstructionBase.constructorof(obj::Type{<:ScheduleConstraint})
    return (args...) -> (obj(args...))
end
