import { z } from 'zod';

export const TelegramUserSchema = z.object({
  id: z.number().int(),
  is_bot: z.boolean().optional(),
  first_name: z.string(),
  last_name: z.string().optional(),
  username: z.string().optional(),
  language_code: z.string().optional(),
  is_premium: z.boolean().optional(),
  added_to_attachment_menu: z.boolean().optional(),
  allows_write_to_pm: z.boolean().optional(),
  photo_url: z.string().url().optional(),
});

export type TelegramUser = z.infer<typeof TelegramUserSchema>;

export const MeResponseSchema = z.object({
  user: TelegramUserSchema,
  authDate: z.number().int(),
});

export type MeResponse = z.infer<typeof MeResponseSchema>;

export const ErrorResponseSchema = z.object({
  error: z.string(),
  message: z.string().optional(),
});

export type ErrorResponse = z.infer<typeof ErrorResponseSchema>;
