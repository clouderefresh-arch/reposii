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

export const TaskSchema = z.object({
  id: z.number().int().positive(),
  userId: z.number().int(),
  title: z.string().min(1).max(200),
  done: z.boolean(),
  createdAt: z.number().int(),
  updatedAt: z.number().int(),
});

export type Task = z.infer<typeof TaskSchema>;

export const TaskListResponseSchema = z.object({
  tasks: z.array(TaskSchema),
});

export type TaskListResponse = z.infer<typeof TaskListResponseSchema>;

export const CreateTaskRequestSchema = z.object({
  title: z.string().trim().min(1).max(200),
});

export type CreateTaskRequest = z.infer<typeof CreateTaskRequestSchema>;

export const UpdateTaskRequestSchema = z
  .object({
    title: z.string().trim().min(1).max(200).optional(),
    done: z.boolean().optional(),
  })
  .refine((data) => data.title !== undefined || data.done !== undefined, {
    message: 'At least one field (title or done) must be provided',
  });

export type UpdateTaskRequest = z.infer<typeof UpdateTaskRequestSchema>;
