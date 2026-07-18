// Airlangga QR Quest — halaman web soal.
// Membaca ?id=<docId> dari URL, mengambil soal dari Firestore, menampilkannya.
// Read-only: peserta menyalin soal dan menjawab di kertas.

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  getFirestore,
  doc,
  getDoc,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

// Alur baca:
//   QR memuat ?slot=<slotId> (token stabil, tercetak sekali).
//   slot -> quest_slots/<slotId>.questionIds -> pilih SATU soal acak ->
//   quest_questions/<questionId>.
// Sebuah slot (pos) bisa berisi banyak soal; tiap pemindaian menampilkan satu
// soal acak. Isi kumpulan bisa diubah/diacak tanpa mengganti QR. Format lama
// (field questionId tunggal, atau parameter ?id= langsung) tetap didukung.

const firebaseConfig = {
  apiKey: "AIzaSyA6AS-OyhHjoEDjbWCQDf1XNmPs0pl-kQw",
  authDomain: "database-7069a.firebaseapp.com",
  projectId: "database-7069a",
  storageBucket: "database-7069a.firebasestorage.app",
  messagingSenderId: "454602570021",
  appId: "1:454602570021:web:51fcf11ab2f228372e02cc",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const $ = (id) => document.getElementById(id);

function show(state) {
  for (const s of ["loading", "error", "question"]) {
    $(`state-${s}`).classList.toggle("hidden", s !== state);
  }
}

function showError(title, msg) {
  $("error-title").textContent = title;
  $("error-msg").textContent = msg;
  show("error");
}

function pickRandom(list) {
  return list[Math.floor(Math.random() * list.length)];
}

async function resolveQuestionId(params) {
  // Slot: token stabil di QR. Ambil kumpulan soal lalu pilih satu acak.
  const slot = params.get("slot");
  if (slot) {
    const slotSnap = await getDoc(doc(db, "quest_slots", slot));
    if (!slotSnap.exists()) return { error: ["QR tidak dikenali", "Slot mungkin sudah dihapus."] };
    const data = slotSnap.data() || {};
    // Format baru: array questionIds. Format lama: questionId tunggal.
    let ids = Array.isArray(data.questionIds) ? data.questionIds.filter(Boolean) : [];
    if (ids.length === 0 && typeof data.questionId === "string" && data.questionId) {
      ids = [data.questionId];
    }
    if (ids.length === 0) {
      // Debug mode: tampilkan isi mentah slot untuk mempercepat diagnosis.
      if (params.get("debug") === "1") {
        return {
          error: [
            "Belum ada soal (debug)",
            `slotId=${slot} • fields=${Object.keys(data).join(",") || "-"} • questionIds=${JSON.stringify(data.questionIds)} • questionId=${JSON.stringify(data.questionId)}`,
          ],
        };
      }
      return { error: ["Belum ada soal", "Slot ini belum diisi soal."] };
    }
    return { id: pickRandom(ids) };
  }
  // Kompatibilitas lama: ?id= langsung ke soal.
  const id = params.get("id");
  if (id) return { id };
  return { error: ["Link tidak valid", "QR tidak memuat kode slot."] };
}

async function main() {
  const params = new URLSearchParams(window.location.search);

  try {
    const resolved = await resolveQuestionId(params);
    if (resolved.error) {
      showError(resolved.error[0], resolved.error[1]);
      return;
    }

    const snap = await getDoc(doc(db, "quest_questions", resolved.id));

    if (!snap.exists()) {
      showError("Soal tidak ditemukan", "Soal mungkin sudah dihapus.");
      return;
    }

    const data = snap.data();

    if (data.aktif === false) {
      showError("Soal belum aktif", "Soal ini sedang tidak ditampilkan.");
      return;
    }

    $("q-kode").textContent = data.kode || "Soal";
    const poin = Number(data.poin) || 0;
    $("q-poin").textContent = `${poin} poin`;
    $("q-text").textContent = data.pertanyaan || "";
    document.title = `${data.kode || "Soal"} — Airlangga QR Quest`;
    show("question");
  } catch (e) {
    console.error(e);
    showError("Gagal memuat soal", "Periksa koneksi internet lalu coba lagi.");
  }
}

main();
