local uv = vim.loop

-- Получение списка файлов и папок в директории
local function get_files_in_directory(path)
    local files = { "       .." } -- Таблица для хранения файлов
    local status_map = {}

    local handle = io.popen("git -C " .. path .. " status --porcelain")
    if handle then
      for line in handle:lines() do
        local x, y, file = line:match("^(.)(.)%s+(.*)$")
        if x and y and file then
          status_map[file] = { x = x, y = y}
        end
      end
      handle: close()
    end

    local handle = uv.fs_scandir(path)
    if handle then
      while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then break end
        local full_name = name .. (type == "directory" and "/" or "")
        local status = status_map[name] or {x = "J", y = "J"}
        local icon = ""
        local icon2 = ""

        if status.x == "M" and status.y == "M" then
          icon = "[v]"
          icon2 = "[x] "
        elseif status.x == "M" and status.y == " " then
          icon = "[v]"
          icon2 = "    "
        elseif status.x == " " and status.y == "M" then
          icon = "[x]"
          icon2 = "    "
        elseif status.x == "A" and status.y == " " then
          icon = "[+]"
          icon2 = "    "
        elseif status.x == "A" and status.y == "M" then
          icon = "[+]"
          icon2 = "[x] "
        elseif status.x == "D" or status.y == "D" then
          icon = "[D]"
          icon2 = "    "
        elseif status.x == "?" or status.y == "?" then
          icon = "[?]"
          icon2 = "    "
        else
          icon = "    "
          icon2 = "   "
        end

        table.insert(files, icon .. icon2 .. full_name)

      end
    end

    return files
end

-- Создание окна с файловым браузером
local function create_file_explorer()
    local current_dir = vim.fn.getcwd() --Берем текущую директорию

    local files = get_files_in_directory(current_dir) --Находим все файлы в директории

    local buf = vim.api.nvim_create_buf(false, true) -- создаем новый буфер false = не влючать буфер в список видимых буферов
                                                                        --  true = временный буфер, без сохранения на диск

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, files) -- установка строк в буфере
                                                         -- buf = id буфера
                                                         -- 0, -1 = диапазн строк для замены
                                                         -- false = проверка на существование индекса
                                                         -- lines = таблица строк

    local width = math.floor(vim.o.columns * 0.4)
    local height = math.floor(vim.o.lines * 0.6)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, { -- Открывает новое окно, привязанное к указанному буферу
        relative = 'editor',                       -- buf = id буфера
        width = width,                             -- true = сделать окно активным
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
    })

    -- Настройка клавиш
    -- buf = id буффера
    -- mode = режим (n (normal), i (insert), v (visual), etc...)
    -- '<CR>' = комбинация клавиш
    -- ":lua require("GitPlugin")...." = команда или фукнция, вызываемая при нажатии
    -- options = таблица параметров
    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>', ':lua require("GitPlugin").handle_selection()<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'a', ':lua require("GitPlugin").git_add()<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'c', ':lua require("GitPlugin").git_commit()<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':lua require("GitPlugin").close_explorer()<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'd', ':lua require("GitPlugin").git_remove()<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'A', ':lua require("GitPlugin").git_add_all()<CR>', { noremap = true, silent = true })

    --Устанавливает переменную для указанного буфера (в буфере buf = id буфера, 'files' = название переменной, files = значение переменной
    vim.api.nvim_buf_set_var(buf, 'files', files)
    vim.api.nvim_buf_set_var(buf, 'dir', current_dir)

    return buf, win
end

-- Обработка выбора файла/папки
local function handle_selection()
    local buf = vim.api.nvim_get_current_buf() -- находим id текущего буфера

    local files = vim.api.nvim_buf_get_var(buf, 'files') --Копируем список файлов
    local dir = vim.api.nvim_buf_get_var(buf, 'dir') --Находим текущую директорию

    local line = vim.api.nvim_win_get_cursor(0)[1] --Находим позицию курсора (0 = окно, {line, col} - возвращаемое значение, индексация с 1)
    local file = files[line] --находим файл, на котором стоит курсор
    local file_sub = ""
    file_sub = string.sub(file, 8)

    if not file_sub then
        vim.notify("Ошибка: выбранный файл не найден.", vim.log.levels.ERROR)
        return
    end

    if file_sub == ".." then
        -- Open ".."
        local parent_dir = vim.fn.fnamemodify(dir, ":h")
        vim.cmd("cd " .. parent_dir)
    elseif file_sub:sub(-1) == "/" then
        -- Open dir
        local new_dir = dir .. "/" .. file_sub:sub(1, -2)
        vim.cmd("cd " .. new_dir)
    else
        -- Open file
        local file_path = dir .. "/" .. file_sub
        local ok, err = pcall(vim.cmd, "edit " .. file_path)
        if not ok then
            vim.notify("Не удалось открыть файл: " .. err, vim.log.levels.ERROR)
        end
    end

    -- Обновляем файловый браузер
    require('GitPlugin').close_explorer()
    require('GitPlugin').create_file_explorer()
end

-- Добавление файла в git
local function git_add()
    local buf = vim.api.nvim_get_current_buf()

    local files = vim.api.nvim_buf_get_var(buf, 'files')
    local dir = vim.api.nvim_buf_get_var(buf, 'dir')

    local line = vim.api.nvim_win_get_cursor(0)[1]
    local file = files[line]
    local file_sub = string.sub(file, 8)
    if not file_sub or file_sub:sub(-1) == "/" or file_sub == ".." then
        vim.notify("Ошибка: можно добавить только файлы.", vim.log.levels.ERROR)
        return
    end

    local file_path = dir .. "/" .. file_sub
    vim.fn.system("git add " .. file_path)
    vim.notify("Файл добавлен в индекс: " .. file_path, vim.log.levels.INFO)

    require('GitPlugin').close_explorer()
    require('GitPlugin').create_file_explorer()
end

local function git_add_all()
    vim.fn.system("git add --all")

    require('GitPlugin').close_explorer()
    require('GitPlugin').create_file_explorer()
end

-- Выполнение git commit
local function git_commit()
    local message = vim.fn.input("Введите сообщение коммита: ")
    if message == "" then
        vim.notify("Сообщение коммита не может быть пустым.", vim.log.levels.ERROR)
        return
    end

    local output = vim.fn.system("git commit -m " .. vim.fn.shellescape(message))
    vim.notify("\nРезультат git commit:\n" .. output, vim.log.levels.INFO)

    require('GitPlugin').close_explorer()
    require('GitPlugin').create_file_explorer()
end

-- Закрытие окна
local function close_explorer()
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_close(win, true)
end

local function git_remove()
    local buf = vim.api.nvim_get_current_buf() -- Получаем текущий буфер
    local files = vim.api.nvim_buf_get_var(buf, 'files') -- Получаем список файлов
    local dir = vim.api.nvim_buf_get_var(buf, 'dir') -- Текущая директория

    -- Which file choosed
    local line = vim.api.nvim_win_get_cursor(0)[1] -- Current line
    local file = files[line]
    if not file then
        vim.notify("Ошибка: выбранный файл не найден.", vim.log.levels.ERROR)
        return
    end

    --Delete symbols
    local file_sub = string.sub(file, 8)

    -- Проверяем, что выбранный объект не является директорией или родительским каталогом
    if not file_sub or file_sub:sub(-1) == "/" or file_sub == ".." then
        vim.notify("Ошибка: можно удалить только файлы.", vim.log.levels.ERROR)
        return
    end

    -- Формируем полный путь файла
    local file_path = dir .. "/" .. file_sub

    -- Выполняем git rm
    local output = vim.fn.system("git rm --cached " .. vim.fn.shellescape(file_path))
    if vim.v.shell_error ~= 0 then
        vim.notify("Ошибка при удалении файла из индекса: " .. output, vim.log.levels.ERROR)
    else
        vim.notify("Файл удалён из индекса: " .. file_path, vim.log.levels.INFO)
    end

    -- Обновляем файловый браузер
    require('GitPlugin').close_explorer()
    require('GitPlugin').create_file_explorer()
end

local M = {}

function M.run_my_plugin()
  create_file_explorer()
end

M.create_file_explorer = create_file_explorer
M.handle_selection = handle_selection
M.git_add = git_add
M.git_commit = git_commit
M.close_explorer = close_explorer
M.git_remove = git_remove
M.git_add_all = git_add_all

vim.api.nvim_create_user_command(
  "GitManager",
  function()
    M.run_my_plugin()
  end,
  {
    desc = "Start Plugin"
  }
)

return M
