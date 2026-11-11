class_name Tr
extends RefCounted
## Перевод интерфейса. Ключ — русская строка; если язык английский и перевод есть — английская.
## Сюжетные тексты (диалоги, задания, записки) лежат отдельно: data/en/...

static func t(s: String) -> String:
	if Settings.lang == "en":
		return EN.get(s, s)
	return s


static func data_path(file: String) -> String:
	# data/quests.json → data/en/quests.json (если есть английская версия)
	if Settings.lang == "en":
		var en := file.replace("res://data/", "res://data/en/")
		if FileAccess.file_exists(en):
			return en
	return file


const EN := {
	# имена
	"Ольдрих": "Oldrich", "Борта": "Borta", "Лия": "Lia", "Мара": "Mara", "Вейл": "Vale",
	"Корней": "Korney", "Ансар": "Ansar", "Король": "The King",
	# области
	"Тихий Брод": "Quiet Ford", "Шепчущий лес": "Whispering Wood", "Топь": "The Mire",
	"Горная обсерватория": "Mountain Observatory", "Руины замка": "Castle Ruins",
	# подсказки действий
	"E — поговорить: ": "E — talk: ", "Поговорить: ": "Talk: ",
	"E — прочитать указ": "E — read the decree", "Прочитать указ": "Read the decree",
	"E — зажечь маяк": "E — light the beacon", "Зажечь маяк": "Light the beacon",
	"E — переправиться": "E — cross over", "Переправиться": "Cross over",
	"E — разжечь жаровню": "E — light the brazier", "Разжечь жаровню": "Light the brazier",
	"E — рассмотреть фреску": "E — study the fresco", "Рассмотреть фреску": "Study the fresco",
	"E — поднять страницу": "E — pick up the page",
	# уведомления
	"Старейшина Ольдрих ждёт у своего дома": "Elder Oldrich is waiting by his house",
	"Шепчущий лес. Здесь тише, чем в тишине.": "The Whispering Wood. It is quieter here than silence.",
	"Топь. Здесь даже тишина вязкая.": "The Mire. Even the silence here is thick.",
	"Горы. Ветер здесь холоднее, чем память.": "The mountains. The wind here is colder than memory.",
	"Трясина! Назад, пока не затянуло…": "A bog! Back, before it pulls you under…",
	"Холод пробирает до костей. Фонарь дрожит — нужна жаровня.": "The cold cuts to the bone. The lantern trembles — find a brazier.",
	"Пальцы немеют… Огонь вот-вот погаснет.": "Your fingers are numb… The flame is about to die.",
	"Где-то на юге, за мостом, с лязгом поднялась старая решётка.": "Somewhere to the south, beyond the bridge, an old portcullis rose with a clang.",
	"Решётка не поддаётся — будто её держит сама темнота. Горит маяков: %d из 4.": "The portcullis will not move — as if darkness itself holds it. Beacons lit: %d of 4.",
	"Задание выполнено: ": "Quest complete: ", "Новое задание: ": "New quest: ",
	"Получено: ": "Received: ", "Новая запись в журнале: ": "New journal entry: ",
	"Игра сохранена": "Game saved",
	# диалоги
	"коснитесь, чтобы продолжить": "tap to continue", "пробел / E — дальше": "space / E — next",
	"1–%d или мышь": "1–%d or mouse", "Отдать: ": "Give: ", "Передумал.": "Never mind.", "Хорошая вещь.": "A good thing.",
	# журнал
	"Журнал": "Journal", "Задания": "Quests", "Записки": "Notes", "В сумке": "In the bag", "Пусто.": "Empty.",
	"Пока ничего. Ольдрих ждёт у своего дома.": "Nothing yet. Oldrich is waiting by his house.",
	"Пока ни одной. Фонарь освещает не только дорогу.": "None yet. A lantern lights more than the road.",
	"Закрыть  (J)": "Close  (J)",
	# карта
	"Карта": "Map", "M — закрыть": "M — close", "коснитесь, чтобы закрыть": "tap to close",
	# меню, пауза, настройки
	"Последний фонарщик": "The Last Lamplighter",
	"Небо закрыла Пелена. Остался один фонарь.": "The Pall has covered the sky. One lantern remains.",
	"Продолжить": "Continue", "Новая игра": "New game", "Настройки": "Settings", "Выйти": "Quit",
	"Выйти из игры": "Quit game", "Пауза": "Paused", "Начать заново": "Start over",
	"Точно? Весь путь сотрётся — нажми ещё раз": "Sure? Your whole journey will be erased — press again",
	"Громкость": "Volume", "Качество графики": "Graphics quality", "Язык": "Language",
	"Низкое": "Low", "Среднее": "Medium", "Высокое": "High", "Авто": "Auto", "Назад": "Back",
	"Трава и дальность обновятся после перезапуска.": "Grass and draw distance update after a restart.",
	"Загрузка мира…": "Loading the world…",
	"Вид от первого лица": "First-person view",
	". E у двери — выйти.": ". E by the door — go out.",
	"E — войти: ": "E — enter: ",
	"E — выйти": "E — go out",
	"E — зажечь фонарь": "E — light the lamp",
	"E — позвать Звёздочку": "E — call Little Star",
	"Войти: ": "Enter: ",
	"Гул с гор… Пелена надвигается.": "A rumble from the mountains… The Pall is coming.",
	"Добудь смолу с мёртвого дерева. Осторожно: рядом трясина": "Get resin from the dead tree. Careful: a bog is nearby",
	"Зажги маяк на холме над деревней": "Light the beacon on the hill above the village",
	"Зажги маяк над топью": "Light the beacon above the Mire",
	"Зажги последний маяк во дворе замка": "Light the last beacon in the castle courtyard",
	"Зажечь фонарь": "Light the lamp",
	"Звёздочка дома. Расскажи Лие": "Little Star is home. Tell Lia",
	"Звёздочка подняла голову и пошла за светом": "Little Star raised her head and followed the light",
	"Здесь Пелена не достанет. Переждём у огня.": "The Pall can't reach us here. We'll wait by the fire.",
	"Иди на восток, в Топь — по старым мосткам": "Go east to the Mire — along the old boardwalks",
	"Иди на запад, в горы — к каменной лестнице": "Go west to the mountains — to the stone stairway",
	"Иди на север, в Шепчущий лес — там второй маяк": "Go north to the Whispering Forest — the second beacon is there",
	"Ищи маяк в глубине леса. Иди за светлячками, которые летят, а не кружат": "Look for the beacon deep in the forest. Follow the fireflies that fly, not the ones that circle",
	"Найди верёвку на старых мостках": "Find the rope on the old boardwalks",
	"Найди паромщика Корнея — его лодка у островка с хижиной": "Find Korney the ferryman — his boat is by the island with the hut",
	"Отнеси верёвку и смолу Корнею": "Bring the rope and resin to Korney",
	"Пелена надвигается! Укройся в доме или у огня": "The Pall is coming! Shelter in a house or by a fire",
	"Пелена накрыла землю. Масло тает, свет сжимается.": "The Pall has covered the land. Oil melts away, the light shrinks.",
	"Пелена отступила.": "The Pall has retreated.",
	"Пелена снаружи. Переждём у огня.": "The Pall is outside. We'll wait by the fire.",
	"Пелена! Укройся в доме или у живого огня": "The Pall! Shelter in a house or by a living fire",
	"Переправься на лодке Корнея к островку маяка": "Cross on Korney's boat to the beacon island",
	"Поговори с королём": "Talk to the king",
	"Поговори со старейшиной Ольдрихом у колодца": "Talk to Elder Oldrich by the well",
	"Поднимайся к маяку на утёсе. Грейся у жаровен — холод гасит фонарь": "Climb to the beacon on the cliff. Warm up at the braziers — the cold dims the lantern",
	"Позвать Звёздочку": "Call Little Star",
	"Пробел — пропустить": "Space — skip",
	"Решётка на юге поднялась. Иди в руины замка, в тронный зал": "The portcullis in the south is up. Go to the castle ruins, to the throne hall",
	"С гор накатывает волна Пелены! Укройся в доме (E у двери) или у живого огня.": "A wave of the Pall rolls down from the mountains! Shelter in a house (E by the door) or by a living fire.",
	"Ты в доме: ": "You are inside: ",
	"Ты в укрытии. Пережди волну.": "You are sheltered. Wait out the wave.",
	"Фонарь горит: %d из %d": "Lamp lit: %d of %d",
	"дом Лии": "Lia's house",
	"дом Ольдриха": "Oldrich's house",
	"обсерватория": "the observatory",
	"с": "s",
	"хижина Вейла": "Vale's hut",
	"хижина Корнея": "Korney's hut",
	"Вид сверху": "Top-down view",
	"WASD / клик — идти  ·  пробел — поднять фонарь  ·  E — действие  ·  J — журнал  ·  M — карта  ·  V — вид  ·  Esc — пауза": "WASD / click — walk  ·  space — raise lantern  ·  E — act  ·  J — journal  ·  M — map  ·  V — view  ·  Esc — pause",
	"Тап — идти  ·  долгое касание — поднять фонарь": "Tap — walk  ·  long press — raise lantern",
	# финал и титры
	"Конец": "The End", "Спасибо, что прошли этот путь.": "Thank you for walking this road.",
}
