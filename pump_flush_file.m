function pump_flush_file(fid)
%PUMP_FLUSH_FILE Best-effort file flush for MATLAB/MonkeyLogic compatibility.

if exist('fflush', 'builtin') || exist('fflush', 'file')
    fflush(fid);
end
end
