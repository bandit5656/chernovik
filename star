import { createServerFn } from "@tanstack/react-start";
import { getRequestHeader } from "@tanstack/react-start/server";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import type { Database } from "@/integrations/supabase/types";

// ==========================================
// КОНСТАНТЫ И КОНФИГУРАЦИЯ
// ==========================================

const NICHE_LABEL: Record<string, string> = {
  beauty: "Бьюти-мастер (маникюр, педикюр, брови, ресницы, косметология)",
  rows_lashes: "Мастер по бровям и ресницам (оформление, ламинирование, наращивание)",
  nails: "Мастер ногтевого сервиса (маникюр, педикюр, гель-лак, дизайн, подология)",
  hair: "Парикмахер-стилист (стрижки, окрашивание, уходы, укладки)",
  makeup: "Визажист (дневной, вечерний, свадебный макияж, образ)",
  permanent_makeup: "Мастер перманентного макияжа (губы, брови, межресничка)",
  depilation: "Мастер депиляции и эпиляции (шугаринг, воск, лазер, электроэпиляция)",
  epilation_laser: "Мастер лазерной эпиляции и депиляции (шугаринг, воск, лазер)",
  cosmetology: "Эстетический косметолог (чистки, пилинги, инъекции, уход)",
  massage_spa: "Массажист / Мастер коррекции фигуры (SPA, массаж)",
  massage_body: "Массажист / Мастер коррекции фигуры (SPA, массаж)",
  tattoo: "Тату-мастер (мини-тату, графика, цветные работы, перекрытия)",
};

const RANDOM_ANGLES = [
  "Сделай упор на визуальный результат, аккуратность и свежесть работы.",
  "Подай материал через экспертный совет по домашнему уходу и сохранению эффекта.",
  "Раскрой технику работы, стерильность и безопасность материалов.",
  "Зайди через развенчание частых страхов клиентов и мифов о процедуре.",
  "Сфокусируйся на премиальных составах, комфорте и эстетике процесса.",
  "Подай тему в формате 'живой разбор случая' или важной детали, которую замечают мастера."
];

function getRandomAngle(): string {
  return RANDOM_ANGLES[Math.floor(Math.random() * RANDOM_ANGLES.length)];
}

const TONE_HINT: Record<string, string> = {
  friendly: `Тон: живой, теплый, естественный блог мастера. 
Обращайся к аудитории легко ("Девочки,", "Красотки,"), но фокусируйся на результатах работы, а не на заезженных метафорах.`,

  professional: `Тон: экспертный, уверенный, с фокусом на правильную технику, аккуратность, качество материалов и безопасность.`,

  emotional: `Тон: вдохновляющий, передающий вау-эффект от преображения и эстетику работы.`,
};

const MOBILE_LENGTH_LIMITS: Record<string, string> = {
  short: `РЕЖИМ "КОРОТКИЙ" (25–35 слов, 4 строки):
- 1 строчка: Заголовок ЗАГЛАВНЫМИ БУКВАМИ + эмодзи.
- 2 предложения: Суть работы и результат.
- 1 строчка: Призыв записаться.`,

  medium: `РЕЖИМ "СРЕДНИЙ" (45–60 слов, 6–7 строк):
- 1 строчка: Емкий заголовок ЗАГЛАВНЫМИ БУКВАМИ + эмодзи.
- 2 коротких абзаца: Описание эффекта, техники и преимуществ для клиента.
- 1 строчка: Призыв записаться + эмодзи.`,

  long: `РЕЖИМ "РАЗВЕРНУТЫЙ" (70–90 слов, 8–10 строк):
- Заголовок ЗАГЛАВНЫМИ БУКВАМИ + эмодзи.
- Развернутое эстетичное описание процедуры, материалов и ухода.
- Финал с призывом.`,
};

const SMM_RULES = `
ЖЕСТКИЕ ПРАВИЛА СОВРЕМЕННОГО SMM:
1. КАТЕГОРИЧЕСКИ ЗАПРЕЩЕН Markdown! Никаких звездочек (**текст**), решеток (#) и косых кавычек.
2. ТЕКСТ ПИШИ СТРОГО СТРОЧНЫМИ БУКВАМИ (с заглавной только начало предложений). ЗАГЛАВНЫМИ — ТОЛЬКО заголовок!
3. ЭМОДЗИ ОБЯЗАТЕЛЬНЫ: ставь 2–3 эстетичных эмодзи (✨, 🤍, 💫, 🌿, 🖤).
4. НИКАКИХ "СКАЗОК" И ЛИТЕРАТУРНЫХ ШТАМПОВ:
   - КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНЫ выражения вроде: "утро начиналось с тоски", "взгляд как у кошки", "магический взмах", "погрузиться в мир красоты", "это не про красоту, а про время".
   - Пиши по делу: состояние волосков/кожи/ногтей, техника работы мастера (изгиб, выкладка, подбор формы, пигмент, уход), практическая польза для клиента.
5. ИЗОЛЯЦИЯ ЗОНЫ/ПРОЦЕДУРЫ:
   - Пиши СТРОГО про ту зону, которая указана в деталях/направлении. Запрещено упоминать посторонние процедуры!
6. Пустая строка между абзацами.
`;

class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

type SB = SupabaseClient<Database>;

function getSessionSupabase(): { supabase: SB; token: string } {
  const authHeader = getRequestHeader("authorization") ?? getRequestHeader("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    throw new HttpError(401, "Требуется вход в аккаунт");
  }
  const token = authHeader.slice("Bearer ".length).trim();
  if (!token || token.split(".").length !== 3) {
    throw new HttpError(401, "Некорректный токен сессии");
  }

  const SUPABASE_URL = "https://axvjkqedrmdktnmppjjs.supabase.co";
  const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_6cEBudyyZD0lfVuqdDz-jg_JavdQS3A";

  const supabase = createClient<Database>(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    global: {
      headers: { Authorization: `Bearer ${token}`, apikey: SUPABASE_PUBLISHABLE_KEY },
    },
    auth: { storage: undefined, persistSession: false, autoRefreshToken: false },
  });
  return { supabase, token };
}

async function consumeAttemptFromSession() {
  const { supabase, token } = getSessionSupabase();
  const { data: claimsData, error: claimsErr } = await supabase.auth.getClaims(token);
  const userId = claimsData?.claims?.sub as string | undefined;
  if (claimsErr || !userId) {
    throw new HttpError(401, "Сессия недействительна");
  }

  const { data: remaining, error: rpcErr } = await supabase.rpc(
    "consume_ai_attempt" as any,
    { _user_id: userId },
  );

  if (rpcErr) {
    if (rpcErr.message?.includes("NO_ATTEMPTS_LEFT") || (rpcErr as any).code === "P0001") {
      throw new HttpError(
        403,
        "NO_ATTEMPTS_LEFT: бесплатные попытки закончились. Активируйте Premium.",
      );
    }
    throw new HttpError(500, `Ошибка базы данных: ${rpcErr.message}`);
  }

  const remainingNum = typeof remaining === "number" ? remaining : Number(remaining);
  return {
    supabase,
    userId,
    remaining: remainingNum,
    unlimited: remainingNum === -1,
  };
}

async function refundAttempt(supabase: SB, userId: string) {
  try {
    await supabase.rpc("refund_ai_attempt" as any, { _user_id: userId });
  } catch {}
}

function getDeepSeekApiKey(): string {
  const key = process.env.DEEPSEEK_API_KEY;
  if (!key) {
    throw new HttpError(500, "AI конфигурация сломана: отсутствует DEEPSEEK_API_KEY");
  }
  return key;
}

async function callAI(messages: Array<{ role: string; content: string }>, expectJson = false, temperature = 0.70) {
  const apiKey = getDeepSeekApiKey();

  const res = await fetch("https://api.deepseek.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages,
      temperature,
      ...(expectJson ? { response_format: { type: "json_object" } } : {}),
    }),
  });

  if (res.status === 429) throw new HttpError(429, "Превышен лимит запросов к DeepSeek. Попробуйте позже.");
  if (res.status === 402) throw new HttpError(402, "На балансе DeepSeek кончились средства.");
  if (!res.ok) throw new HttpError(res.status, `Ошибка DeepSeek API: ${await res.text()}`);

  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}

async function runWithAttempt<T>(fn: () => Promise<T>): Promise<T & { remaining: number }> {
  const ctx = await consumeAttemptFromSession();
  try {
    const result = await fn();
    return { ...result, remaining: ctx.remaining } as T & { remaining: number };
  } catch (err) {
    await refundAttempt(ctx.supabase, ctx.userId);
    throw err;
  }
}

function cleanMarkdown(text: string): string {
  let cleaned = text
    .replace(/\*\*/g, "")
    .replace(/\*/g, "")
    .replace(/^#+\s*/gm, "")
    .replace(/`/g, "")
    .trim();

  if (cleaned.includes("🛠 ДИАГНОСТИКА СИСТЕМЫ")) {
    cleaned = cleaned.split("🛠 ДИАГНОСТИКА СИСТЕМЫ")[0].trim();
  }
  if (cleaned.includes("🛠 [1. VISION SERVICE]")) {
    cleaned = cleaned.split("🛠 [1. VISION SERVICE]")[0].trim();
  }

  return cleaned;
}

const nicheSchema = z.string().trim().min(1).max(40).optional().default("beauty");

// ==========================================
// 1. ГЕНЕРАЦИЯ ПОСТА (РАЗДЕЛ «ТЕКСТ»)
// ==========================================

export const generatePost = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) =>
    z.object({
      niche: nicheSchema,
      direction: z.string().trim().max(80).optional().default(""),
      length: z.enum(["short", "medium", "long"]),
      postType: z.string().trim().min(1).max(60),
      tone: z.enum(["friendly", "professional", "emotional"]).optional().default("friendly"),
      details: z.string().trim().max(500).optional().default(""),
    }).parse(input),
  )
  .handler(async ({ data }) => {
    return runWithAttempt(async () => {
      const niche = data.niche;
      const targetDirection = data.direction && data.direction.trim().length > 0 
        ? data.direction 
        : "услуги мастера";
      const dynamicAngle = getRandomAngle();

      const system = `Ты — профессиональный бьюти-копирайтер. Пишешь каждый раз УНИКАЛЬНО, без шаблонных зачинов.

Ниша: ${NICHE_LABEL[niche] ?? niche}.
${TONE_HINT[data.tone]}

УГОЛ ПОДАЧИ ДЛЯ ЭТОГО ПОСТА:
${dynamicAngle}

ПРАВИЛА ДЛЯ ЗАГОЛОВКОВ:
- Придумывай СВЕЖИЙ, цепляющий заголовок строго по заданной теме.
- КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНО использовать шаблоны: "СЕКРЕТ ИДЕАЛЬНОГО УТРА", "СЕКРЕТ КРАСОТЫ", "ЭТО НЕ ПРО КРАСОТУ, А ПРО ВРЕМЯ", "ИДЕАЛЬНЫЙ ВЗГЛЯД", "СЕКРЕТ ПУБЛИКИ".

КАТЕГОРИЧЕСКИ ЗАПРЕЩЕННЫЕ ФРАЗЫ В ТЕКСТЕ:
- Никаких "Я подбираю...", "Я помогу вам...", "Каждая девушка мечтает...", "Погрузитесь в атмосферу...".

${SMM_RULES}

ПРИОРИТЕТ №1 (ДЕТАЛИ И ЗОНА):
- Зона/Процедура: "${targetDirection}".
- Детали от мастера: "${data.details}".
- Пиши строго про эту услугу! Запрещено додумывать смежные зоны.

ОБЪЕМ (СТРОГО СОБЛЮДАЙ ЛИМИТИРОВАНИЕ):
${MOBILE_LENGTH_LIMITS[data.length]}`;

      const user = `Сгенерируй пост:
- Ниша: ${NICHE_LABEL[niche] ?? niche}
- Направление / Зона: ${targetDirection}
- Тип поста: ${data.postType}
- ДЕТАЛИ / ТЕМА: ${data.details || "нет"}
- Формат длины: ${data.length.toUpperCase()}
- Уникальный токен генерации: ${Math.random()}`;

      const rawContent = await callAI([
        { role: "system", content: system },
        { role: "user", content: user },
      ], false, 0.75);

      return { text: cleanMarkdown(String(rawContent)) };
    });
  });

// ==========================================
// 2. ГЕНЕРАЦИЯ 5 ИДЕЙ (РАЗДЕЛ «ИДЕИ»)
// ==========================================

export const generateIdeas = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) =>
    z.object({
      niche: nicheSchema,
      direction: z.string().trim().max(80).optional().default(""),
    }).parse(input),
  )
  .handler(async ({ data }) => {
    return runWithAttempt(async () => {
      const niche = data.niche;

      const system = `Ты — топовый SMM-стратег в бьюти-сфере. Придумай 5 РАЗНЫХ, живых и трендовых идей для постов бьюти-мастера.

Ниша: ${NICHE_LABEL[niche] ?? niche}.

ТРЕБОВАНИЯ К ИДЕЯМ:
1. Разнообразие форматов (каждая идея из 5 должна быть в своем формате):
   - Идея 1: Экспертный разбор / Миф или частая ошибка клиентов.
   - Идея 2: Трендовый дизайн / Популярная техника этого сезона.
   - Идея 3: Лайфхак или совет по домашнему уходу.
   - Идея 4: Закулисье / Почему мастер делает именно так (безопасность/носка).
   - Идея 5: Продающий кейс / Было-Стало с фокусом на результат.
2. Длина каждой идеи — строго от 8 до 14 слов! Идея должна быть понятной цельной темой, а не абстрактной фразой (БЕЗ "преображений за 40 минут" и без нереалистичных обещний).
3. Пиши на понятном языке мастериц и их клиентов.

Формат вывода — строго JSON:
{"ideas": ["Идея 1", "Идея 2", "Идея 3", "Идея 4", "Идея 5"]}`;

      const user = data.direction 
        ? `Направление / Зона мастера: ${data.direction}. Время: ${Date.now()}` 
        : `Сгенерируй 5 трендовых идей для ниши. Время: ${Date.now()}`;

      const content = await callAI(
        [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
        true,
        0.80
      );

      try {
        const parsed = JSON.parse(String(content));
        const rawIdeas: string[] = Array.isArray(parsed.ideas) ? parsed.ideas.slice(0, 5) : [];
        const ideas = rawIdeas.map((i) => cleanMarkdown(i));
        return { ideas };
      } catch {
        return { ideas: [] };
      }
    });
  });

// ==========================================
// 3. ОПИСАНИЕ ПО ФОТО И ДО/ПОСЛЕ (РАЗДЕЛ «ФОТО»)
// ==========================================

export const analyzePhoto = createServerFn({ method: "POST" })
  .inputValidator((input: unknown) =>
    z
      .object({
        niche: nicheSchema,
        imageDataUrl: z.string().optional(),
        beforeImageDataUrl: z.string().optional(),
        afterImageDataUrl: z.string().optional(),
        mode: z.enum(["describe", "before_after"]).optional().default("describe"),
        wishes: z.string().trim().max(500).optional().default(""),
      })
      .parse(input),
  )
  .handler(async ({ data }) => {
    return runWithAttempt(async () => {
      const niche = data.niche;
      const currentNicheLabel = NICHE_LABEL[niche] ?? niche;
      const isBeforeAfter = data.mode === "before_after";
      const userWishes = data.wishes ? data.wishes.trim() : "";

      const imagesToAnalyze: string[] = [];
      if (isBeforeAfter) {
        if (data.beforeImageDataUrl) imagesToAnalyze.push(data.beforeImageDataUrl);
        if (data.afterImageDataUrl) imagesToAnalyze.push(data.afterImageDataUrl);
      } else {
        const single = data.imageDataUrl || data.afterImageDataUrl;
        if (single) imagesToAnalyze.push(single);
      }

      let photoDescription = "";

      if (imagesToAnalyze.length > 0) {
        const openRouterKey = process.env.OPENROUTER_API_KEY;
        const geminiKey = process.env.GEMINI_API_KEY;

        let targetModels = [
          "google/gemini-2.0-flash-exp:free",
          "meta-llama/llama-3.2-11b-vision-instruct:free",
          "qwen/qwen-2-vl-7b-instruct:free",
        ];

        if (openRouterKey) {
          try {
            const modelsRes = await fetch("https://openrouter.ai/api/v1/models");
            if (modelsRes.ok) {
              const modelsData = await modelsRes.json();
              const freeVisionFromApi = (modelsData.data || [])
                .filter((m: any) => {
                  const id = (m.id || "").toLowerCase();
                  const isFree = id.endsWith(":free");
                  const modalities = m.architecture?.input_modalities || [];
                  const isVision = modalities.includes("image") || modalities.includes("vision");
                  const isSafetyFilter = id.includes("safety") || id.includes("guard");
                  
                  return isFree && isVision && !isSafetyFilter;
                })
                .map((m: any) => m.id);

              if (freeVisionFromApi.length > 0) {
                targetModels = Array.from(new Set([...freeVisionFromApi, ...targetModels]));
              }
            }
          } catch (e) {}

          const visionPromptText = isBeforeAfter
            ? `Внимательно сравни 2 фото. Напиши четко: 1) Состояние ДО и 2) Результат ПОСЛЕ. Учитывай сферу: ${currentNicheLabel}.`
            : `Посмотри на фото работы в сфере (${currentNicheLabel}) и опиши детали выполненной работы.`;

          const contentPayload: any[] = [{ type: "text", text: visionPromptText }];

          for (const img of imagesToAnalyze) {
            const fullDataUrl = img.startsWith("data:") ? img : `data:image/jpeg;base64,${img}`;
            contentPayload.push({
              type: "image_url",
              image_url: { url: fullDataUrl },
            });
          }

          for (const modelName of targetModels) {
            try {
              const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
                method: "POST",
                headers: {
                  "Authorization": `Bearer ${openRouterKey}`,
                  "Content-Type": "application/json",
                },
                body: JSON.stringify({
                  model: modelName,
                  messages: [{ role: "user", content: contentPayload }],
                }),
              });

              if (res.ok) {
                const resData = await res.json();
                const rawResponse = resData.choices?.[0]?.message?.content ?? "";
                
                if (rawResponse.trim().length > 0 && !rawResponse.toLowerCase().includes("user safety")) {
                  photoDescription = rawResponse;
                  break;
                }
              }
            } catch (e) {}
          }
        }

        if (!photoDescription && geminiKey) {
          try {
            const inlineDataParts = imagesToAnalyze.map((img) => {
              const base64Data = img.includes(",") ? img.split(",")[1] : img;
              return { inline_data: { mime_type: "image/jpeg", data: base64Data } };
            });

            const promptText = isBeforeAfter 
              ? `Опиши детали работы ДО и ПОСЛЕ для ниши ${currentNicheLabel}.`
              : `Опиши детали снимка работы для ниши ${currentNicheLabel}.`;

            const payload = { contents: [{ parts: [{ text: promptText }, ...inlineDataParts] }] };

            const googleUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`;
            const res = await fetch(googleUrl, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(payload),
            });

            if (res.ok) {
              const resData = await res.json();
              photoDescription = resData.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
            }
          } catch (e) {}
        }
      }

      const hasVisionFacts = Boolean(photoDescription && photoDescription.trim().length > 0);

      if (isBeforeAfter) {
        const systemBeforeAfter = `Ты — опытный бьюти-мастер в нише "${currentNicheLabel}". Составь профессиональный пост "ДО / ПОСЛЕ".
${SMM_RULES}

СТРОГОЕ ОГРАНИЧЕНИЕ ПО ЗОНЕ:
- Если мастер указал конкретное направление (например: "${userWishes}"), пиши ИСКЛЮЧИТЕЛЬНО про эту процедуру!
- ЗАПРЕЩЕНО упоминать брови, если речь только про ресницы, и наоборот.

ПРАВИЛА ДЛЯ ЗАГОЛОВКА В РЕЖИМЕ "ДО / ПОСЛЕ":
- Заголовок должен отражать СУТЬ УСЛУГИ И РЕЗУЛЬТАТА (например: "ОБЪЕМНОЕ НАРАЩИВАНИЕ 3D ✨", "ЭФФЕКТ ЛАМИНИРОВАНИЯ 🤍").
- КАТЕГОРИЧЕСКИ ЗАПРЕЩЕНЫ слова "Секрет идеального утра", "Идеальный комплекс" (если услуга только одна).

СТРУКТУРА ПОСТА (50–65 СЛОВ):
1. Заголовок ЗАГЛАВНЫМИ БУКВАМИ + эмодзи.
2. ДО: Опиши исходное состояние зоны.
3. ПОСЛЕ: Опиши результат работы.
4. Призыв записаться в 1 короткую строку + эмодзи.

${userWishes ? `УСЛУГА/ЗОНА ОТ МАСТЕРА: "${userWishes}".` : ""}
${hasVisionFacts ? `ФАКТЫ С ФОТО: ${photoDescription}` : ""}`;

        const rawContent = await callAI([
          { role: "system", content: systemBeforeAfter },
          { role: "user", content: `Сгенерируй пост До/После. Ниша: ${currentNicheLabel}. Услуга: ${userWishes}. Seed: ${Math.random()}` },
        ], false, 0.70);

        return { text: cleanMarkdown(String(rawContent)) };
      }

      const systemDescribe = `Ты — мастер в нише "${currentNicheLabel}". Составь понятный, эстетичный пост к фото работы.
${SMM_RULES}

СТРОГОЕ ОГРАНИЧЕНИЕ ПО ЗОНЕ:
- Фокусируйся ТОЛЬКО на услуге: "${userWishes || currentNicheLabel}". 
- НЕ УПОМИНАЙ брови, если услуга — ресницы. НЕ УПОМИНАЙ ресницы, если услуга — брови.

ЗАГОЛОВОК:
- Придумай короткий заголовок строго про выполненную работу (без фразы "Секрет идеального утра" и без слова "Комплекс", если это одна услуга).

ОБЪЕМ (СТРОГО 40–55 СЛОВ):
- Заголовок ЗАГЛАВНЫМИ БУКВАМИ + эмодзи.
- 2 коротких абзаца: профессиональное описание результата.
- 1 строчка с призывом записаться.

${userWishes ? `ОСНОВНОЙ АКЦЕНТ: "${userWishes}".` : ""}
${hasVisionFacts ? `ФАКТЫ С ФОТО: ${photoDescription}` : `Сфера: ${currentNicheLabel}`}`;

      const userText = `Составь пост к снимку. Детали: ${userWishes || photoDescription || currentNicheLabel}. Seed: ${Math.random()}`;

      const rawContent = await callAI([
        { role: "system", content: systemDescribe },
        { role: "user", content: userText },
      ], false, 0.70);

      return { text: cleanMarkdown(String(rawContent)) };
    });
  });
