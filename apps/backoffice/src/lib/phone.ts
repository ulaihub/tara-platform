/** Mobile camerounais saisi librement (« 6 77 12 34 56 », « +237… ») → « +2376XXXXXXXX », ou null. */
export function cameroonMobile(input: string): string | null {
  const digits = input.replace(/\D/g, '').replace(/^(00)?237(?=\d{9}$)/, '');
  return /^6\d{8}$/.test(digits) ? `+237${digits}` : null;
}

/** « +237677123456 » → « +237 6 77 12 34 56 ». */
export function displayPhone(phone: string): string {
  const digits = phone.replace(/\D/g, '').replace(/^237/, '');
  if (digits.length !== 9) return phone;
  return `+237 ${digits[0]} ${digits.slice(1, 3)} ${digits.slice(3, 5)} ${digits.slice(5, 7)} ${digits.slice(7)}`;
}
