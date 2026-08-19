#!/usr/bin/env python3
"""Build the explicit educational override layer from the reviewed source bank.

This is an authoring tool, not a production fallback. The generated files are
committed and reviewed; build_content.py consumes those explicit records.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import build_content

ROOT = Path(__file__).resolve().parents[1]

TOPIC_TEACHING = {
    "Международные правила, ITU, IARU и CEPT": "Любительская служба является одной из радиослужб: её назначение, допустимый обмен и защита частот задаются правилами, а не удобством отдельного оператора.",
    "Российские правила, категории, позывные и разрешительные документы": "Здесь проверяется конкретная норма экзаменационного банка. Отделяйте разрешение на использование частот, квалификацию оператора, категорию станции и правила образования позывного.",
    "Проведение радиосвязи, рапорты и ретрансляторы": "Радиообмен строится так, чтобы частота оставалась понятной и доступной другим: сначала слушают эфир, затем называют позывные и передают только нужную информацию.",
    "Q-коды, аппаратный журнал и QSL": "Q-код — трёхбуквенное сокращение стандартной фразы. Похожие коды нельзя угадывать по одной букве: у каждого своё устойчивое значение.",
    "Виды излучения, модуляция и спектры": "Модуляция переносит речь или данные изменением параметра несущего колебания. AM меняет амплитуду, FM — частоту, а CW передаёт телеграф включением несущей.",
    "Назначение узлов радиостанции": "Читайте тракт по функции каждого блока: один узел усиливает, другой ослабляет, фильтрует, преобразует частоту или выделяет полезный сигнал.",
    "Органы управления, передатчики и приёмники": "Надпись на органе управления указывает не на результат «вообще», а на конкретный параметр тракта: полосу, усиление, частоту, шумоподавление или режим передачи.",
    "Антенны, фидеры, согласование и КСВ": "Передатчик, линия питания и антенна образуют единый ВЧ-тракт. Несогласование создаёт отражённую волну, нагрев и дополнительное излучение фидера.",
    "Распространение радиоволн": "Путь радиоволны зависит от частоты и среды. Земная поверхность, тропосфера, ионосфера, метеорные следы и аврора дают разные механизмы прохождения.",
    "Электрические величины, частота, волна и мощность": "Сначала назовите искомую величину и её единицу, затем выберите связь: U = I·R, P = U·I, T = 1/f или λ = c/f.",
    "Цепи постоянного и переменного тока, RLC и трансформаторы": "Резистор ограничивает ток, конденсатор накапливает энергию электрического поля, катушка — магнитного. На переменном токе C и L зависят от частоты.",
    "Источники питания, формы сигналов и измерения": "Прибор подключают по смыслу измерения: напряжение — параллельно, ток — последовательно. Осциллограф показывает изменение напряжения во времени.",
    "Полупроводники, усилители и операционные усилители": "Транзистор — управляемый полупроводниковый прибор. У биполярного транзистора база управляет током между коллектором и эмиттером; схема включения определяет усиление и фазу.",
    "Колебательные контуры, фильтры, генераторы, ФАПЧ и DSP": "LC-контур обменивается энергией между электрическим полем C и магнитным полем L. Фильтр выбирает частоты, генератор создаёт колебания, ФАПЧ сравнивает и подстраивает фазу.",
    "Структуры приёмников и передатчиков": "Структурную схему читают по ходу сигнала. В супергетеродине смеситель объединяет входной сигнал с гетеродином и создаёт промежуточную частоту для дальнейшей фильтрации.",
    "Антенны и поляризация: углублённые вопросы": "Геометрия антенны задаёт распределение тока и напряжения, направление максимального излучения и поляризацию электрического поля.",
    "Измерения, мощности и проверка аппаратуры": "Перед измерением определите величину, единицу и безопасный способ включения прибора. Эквивалент нагрузки принимает ВЧ-мощность без излучения в эфир.",
    "Электро-, грозо- и пожарная безопасность": "Сначала устраняют источник опасности, не касаясь пострадавшего или оборудования под напряжением. Затем вызывают помощь и действуют по правилам первой помощи и пожарной безопасности.",
    "Радиопомехи, побочные излучения и гармоники": "Помеха на многих каналах обычно указывает на перегрузку входа, а помеха на отдельных частотах — на гармоники или побочные излучения. Диагноз определяет способ устранения.",
}

KNOWN_MEANINGS = {
    "ватт": "ватт измеряет мощность",
    "вольт": "вольт измеряет напряжение",
    "ампер": "ампер измеряет ток",
    "ом": "ом измеряет сопротивление",
    "фарад": "фарад измеряет электрическую ёмкость",
    "генри": "генри измеряет индуктивность",
    "герц": "герц измеряет частоту",
    "джоуль": "джоуль измеряет энергию",
    "qso": "QSO означает радиосвязь",
    "qsl": "QSL означает подтверждение приёма или связи",
    "qsy": "QSY означает смену частоты",
    "qrt": "QRT означает прекращение работы в эфире",
    "qrm": "QRM обозначает помехи от других станций",
    "qrn": "QRN обозначает атмосферные помехи",
    "qrz": "QRZ — вопрос о том, кто вызывает",
    "cw": "CW — телеграфное включение и выключение несущей",
    "am": "AM изменяет амплитуду несущей",
    "fm": "FM изменяет мгновенную частоту несущей",
    "ssb": "SSB передаёт одну боковую полосу с подавленной несущей",
}

GENERIC_SOURCE_MARKERS = (
    "Правильный ответ:",
    "Вопрос проверяет базовую связь",
    "Это стандартная процедура",
    "Используй базовые электрические связи",
    "Вопрос проверяет поведение реактивных элементов",
    "Это вопрос о прохождении радиоволн",
    "Проследи путь сигнала по блокам аппаратуры",
)


def compact(value: str) -> str:
    return " ".join(value.strip().split())


def definitions_for(question: dict, entries: list[dict]) -> tuple[list[str], list[str]]:
    terms = build_content.matched_terms(question, entries)
    lines = [f"{entry['term']} — {entry['shortDefinition']}" for entry in terms[:4]]
    return [entry["id"] for entry in terms], lines


def reviewed_short(question: dict, entries: list[dict]) -> str:
    source = compact(question["explanationShort"])
    if not any(marker in source for marker in GENERIC_SOURCE_MARKERS):
        return source
    correct = compact(question["officialCorrectAnswerText"])
    correct_lowered = correct.lower().replace("ё", "е")
    facts = [meaning for key, meaning in KNOWN_MEANINGS.items() if re.search(rf"(?<![a-zа-я]){re.escape(key)}(?![a-zа-я])", correct_lowered)]
    if facts:
        return f"{'; '.join(dict.fromkeys(facts)).capitalize()}. Поэтому в вопросе № {question['examNumber']} выбирают «{correct}», а варианты с другими единицами или обозначениями относятся к другим величинам."
    _, definitions = definitions_for(question, entries)
    definition = f" Опорное понятие: {definitions[0]}." if definitions else ""
    return f"{TOPIC_TEACHING[question['topic']]} Конкретный вывод для вопроса № {question['examNumber']}: {correct}.{definition}"


def numeric_values(value: str) -> list[float]:
    result = []
    for token in re.findall(r"(?<![A-Za-zА-Яа-я])\d+(?:[.,]\d+)?", value):
        try:
            result.append(float(token.replace(",", ".")))
        except ValueError:
            pass
    return result


def specific_wrong(question: dict, option: dict, correct: str, source: str) -> str:
    wrong = compact(option["text"])
    lowered = wrong.lower().replace("ё", "е")
    correct_lowered = correct.lower().replace("ё", "е")
    facts = [
        meaning for key, meaning in KNOWN_MEANINGS.items()
        if re.search(rf"(?<![a-zа-я]){re.escape(key)}(?![a-zа-я])", lowered)
        and not re.search(rf"(?<![a-zа-я]){re.escape(key)}(?![a-zа-я])", correct_lowered)
    ]
    if facts:
        fact = "; ".join(dict.fromkeys(facts))
        return f"Вариант «{wrong}» подменяет проверяемое понятие: {fact}. В этом вопросе нужно применить другое точное соответствие: {source} Поэтому вариант банка — «{correct}»."

    wrong_numbers = numeric_values(wrong)
    correct_numbers = numeric_values(correct)
    contrasts = [
        ("вдоль", "перпендикулярно"), ("перпендикулярно", "вдоль"),
        ("кругов", "восьмер"), ("восьмер", "кругов"),
        ("последователь", "параллель"), ("параллель", "последователь"),
        ("прям", "обрат"), ("обрат", "прям"),
        ("увелич", "уменьш"), ("уменьш", "увелич"),
        ("верхн", "нижн"), ("нижн", "верхн"),
    ]
    found_contrasts = [(wrong_part, correct_part) for wrong_part, correct_part in contrasts if wrong_part in lowered and correct_part in correct_lowered]
    if found_contrasts:
        details = ", ".join(f"«{wrong_part}» вместо «{correct_part}»" for wrong_part, correct_part in found_contrasts)
        return f"Вариант «{wrong}» меняет ключевой признак ({details}). Для этой схемы, антенны или процесса установлено: {source} Поэтому верна формулировка «{correct}»."

    if wrong_numbers and correct_numbers and wrong_numbers != correct_numbers and "вариант" not in lowered and "вариант" not in correct_lowered:
        left, right = wrong_numbers[0], correct_numbers[0]
        relation = "больше" if left > right else "меньше"
        return f"Вариант «{wrong}» начинается с значения {left:g}, которое {relation} требуемого {right:g}. Это меняет не округление, а физический параметр или результат расчёта. Проверка даёт: {source} Верный вариант — «{correct}»."

    if wrong.lower().startswith(("только", "ни ", "не ", "всегда", "никогда")):
        return f"Формулировка «{wrong}» вводит слишком жёсткое ограничение или отрицание. Экзаменационное правило сформулировано конкретнее: {source} Следовательно, правильный вариант — «{correct}»."

    topic = question["topic"]
    if topic.startswith(("Международные", "Российские")):
        return f"Формулировка «{wrong}» расширяет, сужает или заменяет конкретную норму из вопроса № {question['examNumber']}. Банк устанавливает: {source} Поэтому разрешение, обязанность или статус из этого варианта неприменимы; верно «{correct}»."
    if topic in {"Проведение радиосвязи, рапорты и ретрансляторы", "Q-коды, аппаратный журнал и QSL"}:
        if ("имя" in lowered or "ник" in lowered) and "позыв" in correct_lowered:
            return f"«{wrong}» использует имя или произвольный ник вместо официального позывного. Они не обеспечивают однозначную идентификацию станции. Установленный порядок таков: {source} Поэтому нужен вариант «{correct}»."
        return f"Действие или порядок «{wrong}» пропускает, добавляет либо переставляет существенный шаг радиообмена. Полная процедура для этой ситуации: {source} Именно её сохраняет «{correct}»."
    if topic in {"Назначение узлов радиостанции", "Органы управления, передатчики и приёмники", "Структуры приёмников и передатчиков"}:
        return f"Вариант «{wrong}» приписывает узлу другую функцию или помещает его не в ту точку тракта. Прослеживание сигнала даёт: {source} Поэтому требуемому блоку или режиму соответствует «{correct}»."
    if topic in {"Антенны, фидеры, согласование и КСВ", "Антенны и поляризация: углублённые вопросы"}:
        return f"В «{wrong}» изменены электрический параметр, геометрия или направление поля антенны. Для конструкции из условия справедливо: {source} Поэтому нужное сочетание свойств дано в «{correct}»."
    if topic in {"Электрические величины, частота, волна и мощность", "Цепи постоянного и переменного тока, RLC и трансформаторы", "Источники питания, формы сигналов и измерения", "Измерения, мощности и проверка аппаратуры"}:
        return f"«{wrong}» относится к другой величине, соединению или результату расчёта. После выбора правильной физической связи получаем: {source} Следовательно, условию соответствует «{correct}»."
    if topic in {"Полупроводники, усилители и операционные усилители", "Колебательные контуры, фильтры, генераторы, ФАПЧ и DSP"}:
        return f"Вариант «{wrong}» описывает другое свойство компонента, каскада или частотной цепи. В рассматриваемой схеме работает принцип: {source} Он соответствует «{correct}»."
    if topic == "Виды излучения, модуляция и спектры":
        return f"«{wrong}» меняет вид модуляции, параметр несущей или состав спектра. Для сигнала из условия действует: {source} Поэтому правильное обозначение или полоса — «{correct}»."
    if topic == "Распространение радиоволн":
        return f"«{wrong}» называет другой механизм или среду распространения, у которых иные частоты и признаки. Здесь наблюдается следующее: {source} Поэтому выбирают «{correct}»."
    if topic == "Электро-, грозо- и пожарная безопасность":
        return f"Действие «{wrong}» не устраняет указанную опасность либо создаёт дополнительный риск. Безопасная последовательность и причина таковы: {source} Поэтому требуется «{correct}»."
    if topic == "Радиопомехи, побочные излучения и гармоники":
        return f"Причина или мера «{wrong}» обычно дала бы другой частотный рисунок помех. Наблюдение из вопроса объясняется так: {source} Поэтому наиболее вероятен вариант «{correct}»."
    return f"Утверждение «{wrong}» меняет условие вопроса № {question['examNumber']}. Предметное объяснение здесь такое: {source} Следовательно, правильная формулировка — «{correct}»."


def beginner_text(question: dict, definitions: list[str], source: str, correct: str) -> str:
    teaching = TOPIC_TEACHING[question["topic"]]
    terms = " ".join(definitions) if definitions else "Специальный термин здесь не нужен: достаточно понять условие и единицы."
    variants = [
        f"Начнём с основы. {terms}. {teaching} Теперь применим это именно к вопросу: {source} Поэтому правильная формулировка экзаменационного банка — «{correct}».",
        f"Сначала разберём слова. {terms}. Представьте путь сигнала или действие оператора шаг за шагом. {teaching} В данном случае {source} Отсюда без угадывания получаем ответ «{correct}».",
        f"Что важно знать с нуля: {terms}. {teaching} Вопрос № {question['examNumber']} проверяет эту связь в конкретной ситуации. {source} Значит, выбирают «{correct}».",
        f"Не запоминайте букву варианта. Опорные понятия: {terms}. {teaching} Сопоставление с условием даёт следующий вывод: {source} Итоговый ответ — «{correct}».",
    ]
    return variants[question["examNumber"] % len(variants)]


def reasoning_text(question: dict, source: str, correct: str) -> str:
    stem = compact(question["stem"])
    topic = question["topic"]
    if topic.startswith(("Международные", "Российские")):
        return f"1. Определите, о какой службе, операторе или разрешении говорится в вопросе: «{stem}». 2. Не расширяйте норму по аналогии с другими службами. 3. Экзаменационный банк фиксирует правило: {source} Этой норме полностью соответствует только «{correct}»."
    if "рисунк" in question.get("type", "").lower() or question.get("figureAsset"):
        return f"1. Проследите рисунок по ходу сигнала и назовите каждый существенный блок или геометрический признак. 2. Сосчитайте преобразования, узлы или направления, не ориентируясь на номер рисунка. 3. Здесь отличительный признак таков: {source} Поэтому выбирают «{correct}»."
    calculation_words = ("чему рав", "рассч", "какую полосу", "какая мощность", "какая частота", "какая индуктивность", "какое сопротивление", "в каких единицах")
    if any(word in stem.lower() for word in calculation_words):
        return f"1. Выпишите, какая величина дана и какая требуется в вопросе «{stem}». 2. Не смешивайте единицы и приставки; сравнивайте значения только после приведения к одному масштабу. 3. Предметная проверка даёт: {source} Поэтому числу, формуле или пределу в условии соответствует «{correct}»."
    if topic in {"Проведение радиосвязи, рапорты и ретрансляторы", "Q-коды, аппаратный журнал и QSL"}:
        return f"1. Выделите требуемую фразу, порядок действий или код в вопросе «{stem}». 2. Проверьте, сохраняет ли вариант однозначность радиообмена. 3. Установленное соответствие: {source} Следовательно, верная процедура или код — «{correct}»."
    return f"1. Назовите физическую величину, устройство или процесс, о котором спрашивает формулировка «{stem}». 2. Свяжите его функцию с причиной, а не только с похожим словом в варианте. 3. Для этого вопроса действует объяснение: {source} Поэтому всем условиям соответствует «{correct}»."


def memory_hint(question: dict, source: str, correct: str) -> str:
    anchors = [sentence.strip() for sentence in re.split(r"(?<=[.!?])\s+", source) if sentence.strip()]
    anchor = anchors[0] if anchors else source
    return f"№ {question['examNumber']}: {anchor} → {correct}"


def curated_entry(question: dict, entries: list[dict]) -> dict:
    source = reviewed_short(question, entries)
    correct = compact(question["officialCorrectAnswerText"])
    term_ids, definitions = definitions_for(question, entries)
    return {
        "explanationShort": source,
        "explanationBeginner": beginner_text(question, definitions, source, correct),
        "explanationReasoning": reasoning_text(question, source, correct),
        "wrongOptionExplanations": {
            option["id"]: specific_wrong(question, option, correct, source)
            for option in question["options"] if option["id"] != question["correctOptionId"]
        },
        "memoryHint": memory_hint(question, source, correct),
        "glossaryTerms": term_ids,
    }


def main() -> None:
    questions = json.loads((ROOT / "ContentRaw" / "questions-imported.json").read_text(encoding="utf-8"))
    corrections = json.loads((ROOT / "ContentOverrides" / "question-overrides.json").read_text(encoding="utf-8")).get("questions", {})
    entries = build_content.glossary()
    buckets = {(1, 100): {}, (101, 200): {}, (201, 300): {}, (301, 426): {}}
    for question in questions:
        question = dict(question)
        number = question["examNumber"]
        if "explanationShort" in corrections.get(str(number), {}):
            question["explanationShort"] = corrections[str(number)]["explanationShort"]
        for (lower, upper), bucket in buckets.items():
            if lower <= number <= upper:
                bucket[str(number)] = curated_entry(question, entries)
                break
    output = ROOT / "ContentOverrides"
    for (lower, upper), payload in buckets.items():
        path = output / f"questions-{lower:03d}-{upper:03d}.json"
        path.write_text(json.dumps({"schemaVersion": 1, "questions": payload}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote {path.relative_to(ROOT)}: {len(payload)} questions")


if __name__ == "__main__":
    main()
