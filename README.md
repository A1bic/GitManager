### GitPlugin

---
# GitPlugin
GitPlugin - плагин для NeoVim, который предоставляет удобный интерфейс для выполнения основных операций с Git. Плагин позволяет работать с файлами, добавлять их в индекс, удалять из индекса, создавать коммит, а также предоставляет минимальный файловый браузер для удобства выбора файлов.  

---

## Установка  

Добавьте в свой основной конфигурационный файл neovim `A1bic/GitManager`  

Добавьте файл конфигурации плагина  
```
require'GitPlugin'  
```

---

## Использование

### Команда

`:GitManager` Открывает файловый браузер и позволяет управлять файлами через Git

### Горячие клавиши
Внутри окна плагина доступны следующие горячие клавиши:  
- `a` - git add  
- `A` - git add *  
- `c` - git commit (Далее предлагается сразу ввести сообщение коммита)  
- `d` - git rm --cached
- `q` - закрыть окно плагина  

---

Разработал плагин: Коваленко Леонид Андреевич 
Группа: M3108
