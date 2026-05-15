#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

namespace {

void CenterWindowInWorkArea(HWND window_handle) {
  if (window_handle == nullptr) {
    return;
  }

  HMONITOR monitor = ::MonitorFromWindow(window_handle, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info;
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (!::GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  RECT window_rect;
  if (!::GetWindowRect(window_handle, &window_rect)) {
    return;
  }

  const RECT work_area = monitor_info.rcWork;
  const int screen_margin = 48;
  const int work_width = work_area.right - work_area.left;
  const int work_height = work_area.bottom - work_area.top;
  const int current_width = window_rect.right - window_rect.left;
  const int current_height = window_rect.bottom - window_rect.top;
  const int width = std::min(current_width, work_width - screen_margin);
  const int height = std::min(current_height, work_height - screen_margin);
  const int left = work_area.left + (work_width - width) / 2;
  const int top = work_area.top + (work_height - height) / 2;

  ::SetWindowPos(window_handle, nullptr, left, top, width, height,
                 SWP_NOZORDER | SWP_NOACTIVATE);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(1664, 936);  // 1280x720 * 1.3
  if (!window.Create(L"Aura SVN", origin, size)) {
    return EXIT_FAILURE;
  }
  CenterWindowInWorkArea(window.GetHandle());
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
