import { Controller } from "@hotwired/stimulus";

const YEAR = 60 * 60 * 24 * 365;

export default class extends Controller {
  static values = { code: String };

  remember() {
    document.cookie = `locale=${this.codeValue}; path=/; max-age=${YEAR}; samesite=lax`;
  }
}
