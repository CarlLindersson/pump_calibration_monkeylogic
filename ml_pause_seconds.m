function ml_pause_seconds(seconds_to_wait)
%ML_PAUSE_SECONDS Wait in seconds, using MonkeyLogic idle when available.

if seconds_to_wait <= 0
    return
end

try
    idle(round(1000 * seconds_to_wait));
catch
    pause(seconds_to_wait);
end
end
