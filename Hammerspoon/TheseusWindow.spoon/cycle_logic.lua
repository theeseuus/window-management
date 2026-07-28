local logic = {}

function logic.nextIndex(currentIndex, count, step)
  if type(count) ~= "number" or count < 1 then
    return nil, "invalid-count"
  end

  step = step or 1
  if type(step) ~= "number" or step == 0 then
    return nil, "invalid-step"
  end

  if currentIndex == nil then
    return step < 0 and count or 1
  end

  return ((currentIndex - 1 + step) % count) + 1
end

return logic
