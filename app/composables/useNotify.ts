interface AlertOptions {
  title?: string;
  message: string;
  state?: 'success' | 'error' | 'warning' | 'info' | 'critical';
}

interface ConfirmOptions {
  title?: string;
  question: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm: () => void | Promise<void>;
}

interface Notification {
  id: number;
  type: 'alert' | 'confirm';
  title?: string;
  message: string;
  state?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  onConfirm?: () => void | Promise<void>;
}

const notifications = ref<Notification[]>([]);
let nextId = 0;

export function useNotify() {
  function alert(options: AlertOptions) {
    const id = nextId++;
    notifications.value.push({
      id,
      type: 'alert',
      title: options.title,
      message: options.message,
      state: options.state ?? 'info',
    });
    setTimeout(() => dismiss(id), 4000);
  }

  function confirm(options: ConfirmOptions) {
    const id = nextId++;
    notifications.value.push({
      id,
      type: 'confirm',
      title: options.title,
      message: options.question,
      confirmLabel: options.confirmLabel,
      cancelLabel: options.cancelLabel,
      onConfirm: options.onConfirm,
    });
  }

  function dismiss(id: number) {
    const index = notifications.value.findIndex((n) => n.id === id);
    if (index > -1) notifications.value.splice(index, 1);
  }

  return { notifications, alert, confirm, dismiss };
}
