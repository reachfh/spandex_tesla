ExUnit.start()
Application.ensure_all_started(:bypass)
Application.ensure_all_started(:spandex)
SpandexDatadog.ApiServer.start_link(batch_size: 1, verbose?: true)
