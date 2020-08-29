@echo off
set FILE_INPUT="%~s1"

set ARGS=
::program switches
set ARGS=%ARGS%  -y  -hide_banner  -loglevel "info"  -stats  -threads "1"  -strict "experimental"
::flags
  set ARGS=%ARGS% -flags              "+naq+low_delay+global_header-unaligned-ilme-cgop-loop-output_corrupt"
  set ARGS=%ARGS% -flags2             "+fast+ignorecrop+showall+export_mvs"
  set ARGS=%ARGS% -fflags             "+ignidx+genpts+nofillin+discardcorrupt-fastseek"
  set ARGS=%ARGS% -movflags           "+faststart+disable_chpl"
  set ARGS=%ARGS% -avoid_negative_ts  "make_zero"
::start/finish
  set ARGS=%ARGS% -ss "00:00:00.001"
::set ARGS=%ARGS% -to "00:00:05.000"
::meta data processing
  set ARGS=%ARGS% -map_chapters  "-1"
  set ARGS=%ARGS% -map_metadata  "-1"
::explicit "audio only" mode
  set ARGS=%ARGS% -sn -vn
::audio processing
  set ARGS=%ARGS% -af "asetpts=PTS-STARTPTS,aresample=async=1:min_hard_comp=0.100000,volume=5.7dB"

set FILE_OUTPUT="%~d1%~p1%~n1_fixed.ogg"

echo.
echo Encoding Audio Stream.
@echo on
call ffmpeg.exe -i %FILE_INPUT% %ARGS% %FILE_OUTPUT%
@echo off

echo.
echo.
