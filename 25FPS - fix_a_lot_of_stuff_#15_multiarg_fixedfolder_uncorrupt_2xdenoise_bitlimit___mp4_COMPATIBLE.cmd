@echo off
chcp 65001          2>nul >nul
mkdir "%~sdp1fixed" 2>nul >nul


:LOOP
::has argument ?
if ["%~1"]==[""] (
  echo done.
  goto END;
)
::argument exist ?
if not exist %~s1 (
  echo not exist
  goto NEXT;
)
::file exist ?
echo exist
if exist %~s1\NUL (
  echo is a directory
  goto NEXT;
)
::OK
echo is a file

::--------------------------------------------------------------------------------

  set "FILE_INPUT=%~s1"
  set "FILE_OUTPUT=%~sdp1fixed\%~n1.mp4"

  set "PROBED_VCODEC="
  set "PROBED_ACODEC="
  for /f "tokens=*" %%a in ('call ffprobe.exe -hide_banner -loglevel error -strict experimental -i %FILE_INPUT% -select_streams "v:0" -show_entries "stream=codec_name" -print_format "default=noprint_wrappers=1:nokey=1"') do (set PROBED_VCODEC=%%a)
  for /f "tokens=*" %%a in ('call ffprobe.exe -hide_banner -loglevel error -strict experimental -i %FILE_INPUT% -select_streams "a:0" -show_entries "stream=codec_name" -print_format "default=noprint_wrappers=1:nokey=1"') do (set PROBED_ACODEC=%%a)

  set "ARGS="

::-------------------------------------------------------------------------------flags
  set ARGS=%ARGS% -flags            "+low_delay+global_header-unaligned-ilme-cgop-loop-output_corrupt"
  set ARGS=%ARGS% -flags2           "+fast+ignorecrop+showall+export_mvs"
  set ARGS=%ARGS% -fflags           "+ignidx+genpts+nofillin+discardcorrupt-fastseek"
  set ARGS=%ARGS% -movflags         "+faststart+disable_chpl"
  set ARGS=%ARGS% -mpv_flags        "+strict_gop+naq"


::only codec_type=mpeg4 supports this
  if /i ["%PROBED_VCODEC%"] EQU ["mpeg4"] (
    set ARGS=%ARGS% -bsf:v                  "mpeg4_unpack_bframes,remove_extra=freq=all"
  ) else (
    set ARGS=%ARGS% -bsf:v                  "remove_extra=freq=all"
  )

  set ARGS=%ARGS% -avoid_negative_ts        "make_zero"
  set ARGS=%ARGS% -segment_time_metadata    "1"
  set ARGS=%ARGS% -force_duplicated_matrix  "1"

  set ARGS=%ARGS% -zerolatency      "1"
  set ARGS=%ARGS% -tune             "zerolatency"

::-------------------------------------------------------------------------------metadata processing
  set ARGS=%ARGS% -map_chapters     "-1"
  set ARGS=%ARGS% -map_metadata     "-1"

::-------------------------------------------------------------------------------encoding-layer restriction (efficient/compatible)
::set ARGS=%ARGS% -profile:v        "high"
::set ARGS=%ARGS% -level            "5.2"
  set ARGS=%ARGS% -profile:v        "baseline"
  set ARGS=%ARGS% -level            "3.0"

::-------------------------------------------------------------------------------motion-estimation
  set ARGS=%ARGS% -subq             "9"
  set ARGS=%ARGS% -refs             "25"
  set ARGS=%ARGS% -motion-est       "esa"
  set ARGS=%ARGS% -me_method        "esa"

::-------------------------------------------------------------------------------frames logic (I,IDR)
::set ARGS=%ARGS% -g                "2"
  set ARGS=%ARGS% -g                "25"
  set ARGS=%ARGS% -strict_gop       "1"
  set ARGS=%ARGS% -intra-refresh    "0"
  set ARGS=%ARGS% -forced-idr       "1"

::-------------------------------------------------------------------------------use I-frames (disable adaptive number of B-frames)
  set ARGS=%ARGS% -b_strategy       "0"
::set ARGS=%ARGS% -x264opts         "keyint=4"

::-------------------------------------------------------------------------------max B frames between reference frames
  set ARGS=%ARGS% -bf               "2"

::-------------------------------------------------------------------------------increase number of lookahead fragments
  set ARGS=%ARGS% -lookahead_count  "4"
  set ARGS=%ARGS% -qcomp            "0.60"
  set ARGS=%ARGS% -rc-lookahead     "25"
  set ARGS=%ARGS% -aq-mode          "variance"

::-------------------------------------------------------------------------------(default 8 or -1 ??)   Reduces blocking and blurring in flat and textured areas. (from -1 to FLT_MAX) (default -1)
  set ARGS=%ARGS% -aq-strength      "1"

::-------------------------------------------------------------------------------(default -1)           Reduce fluctuations in QP (before curve compression)
  set ARGS=%ARGS% -cplxblur         "10"

::-------------------------------------------------------------------------------video processing
  set ARGS=%ARGS% -crf              "23"
  set ARGS=%ARGS% -preset           "veryslow"
  set ARGS=%ARGS% -vsync            "1"

::-------------------------------------------------------------------------------additional buffer, explicit align start, deinterlace, remove duplicate frames(x2 wide/narrow areas), chroma fix, frame-rate fix, crop to even screen-size, frame-rate fix, smooth pixelations.
  set ARGS=%ARGS% -vf               "fifo,setpts=PTS-STARTPTS,yadif=0:-1:0,dejudder=cycle=20,mpdecimate=hi=128*12:lo=128*5:frac=0.10,mpdecimate=hi=8*12:lo=8*5:frac=0.10,format=pix_fmts=yuv420p,fps=fps=25,setpts=N/FRAME_RATE/TB-STARTPTS,crop=trunc(in_w/2)*2:trunc(in_h/2)*2,hqdn3d=luma_spatial=8.0"

::-------------------------------------------------------------------------------limiting bitrate (video)
  set ARGS=%ARGS% -mbd              "rd"
  set ARGS=%ARGS% -minrate:v        "400k"
  set ARGS=%ARGS% -maxrate:v        "700k"
  set ARGS=%ARGS% -bufsize:v        "900k"

::-------------------------------------------------------------------------------limiting bitrate (audio)
  set ARGS=%ARGS% -b:a              "192k"
  set ARGS=%ARGS% -minrate:a        "192k"
  set ARGS=%ARGS% -maxrate:a        "192k"
  set ARGS=%ARGS% -bufsize:a        "256k"



::-------------------------------------------------------------------------------audio processing

::-------------------------------------------------------------------------------try to use MP3 as an audio-codec, unless the input-file is 3gp, which for some reason refuse to accept this codec (use AAC, default).
  set ARGS=%ARGS% -codec:a        "libmp3lame"
::-------------------------------------------------------------------------------force audio sampling-rate, allow converting files-with too-low sampling-rate for MP4 container (for example '.3GP' uses 8K)
  set ARGS=%ARGS% -ar             "48000"


::-------------------------------------------------------------------------------additional buffer, explicit align start.
  set ARGS=%ARGS% -af               "afifo,asetpts=PTS-STARTPTS"

::-------------------------------------------------------------------------------start/finish
  set ARGS=%ARGS% -ss               "00:00:00.011"
::set ARGS=%ARGS% -to               "00:01:00.000"

::-------------------------------------------------------------------------------adjust length to total length of shorter video.
  set ARGS=%ARGS% -shortest



title Processing...
echo.
@echo on
call ffmpeg.exe -y -hide_banner -loglevel "info" -stats -threads "16" -strict "experimental" -i "%FILE_INPUT%" %ARGS% "%FILE_OUTPUT%"
@echo off
echo.
title Done.


::--------------------------------------------------------------------------------

:NEXT
shift
goto LOOP

:END
pause


