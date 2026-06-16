let currentElevatorData = {};
let savedLocations = {};
let globalElevatorsList = [];
let targetDeleteId = null;
let editingElevatorId = null;

window.addEventListener('message', function (event) {
    let data = event.data;

    if (data.action === "openElevatorMenu") {
        document.getElementById('rayka-container').classList.remove('asccochi-hidden');
        switchTab('rayka-create-section');
        resetCreateForm();
        if (data.sqlList) {
            globalElevatorsList = data.sqlList;
            renderElevatorList(globalElevatorsList);
        }
    }
    else if (data.action === "showMenuAgain") {
        const locId = data.locationSavedId;
        if (locId && data.clientCoords) {
            if (!savedLocations[locId]) savedLocations[locId] = {};
            savedLocations[locId].coords = data.clientCoords;
        }
        document.getElementById('rayka-container').classList.remove('asccochi-hidden');
        fetch(`https://${GetParentResourceName()}/toggleMouse`, { method: 'POST', body: JSON.stringify({ enable: true }) });
        updateCheckmarks();
    }

    if (data.action === "showPrompt") {
        document.getElementById('rayka-prompt').classList.remove('asccochi-hidden');
    } else if (data.action === "hidePrompt") {
        document.getElementById('rayka-prompt').classList.add('asccochi-hidden');
    }

    if (data.action === "openSelector") {
        const elevator = data.elevatorData;
        const currentFloorKey = data.currentFloor ? data.currentFloor.toString().trim().toLowerCase() : "";

        document.getElementById('rayka-selector-title').innerText = elevator.name;
        document.getElementById('rayka-selector-job-badge').innerText = elevator.job === "public" ? "Public" : elevator.job;

        const floorsList = JSON.parse(elevator.floors);
        const container = document.getElementById('rayka-selector-floors-list');
        container.innerHTML = '';

        Object.keys(floorsList).forEach(key => {
            const checkKey = key.toString().trim().toLowerCase();
            if (checkKey === currentFloorKey) return;

            let label = floorsList[key].name || `Floor ${key}`;

            container.innerHTML += `
                <div class="asccochi-floor-btn" onclick="teleportToFloor(${elevator.id}, '${key}')">
                    <span class="rayka-floor-name">${label}</span>
                    <i class="fa-solid fa-chevron-right asccochi-floor-icon"></i>
                </div>
            `;
        });

        document.getElementById('rayka-selector').classList.remove('asccochi-hidden');
        fetch(`https://${GetParentResourceName()}/toggleMouse`, { method: 'POST', body: JSON.stringify({ enable: true }) });
    }

    if (data.action === "playSoundSilent") {
        const audio = document.getElementById('rayka-audio');
        if (audio) {
            audio.volume = 0.3;
            audio.currentTime = 0;
            audio.play().catch(e => { });
        }
    }
});

function renderElevatorList(list) {
    const container = document.getElementById('rayka-elevator-list-container');
    if (!container) return;
    container.innerHTML = '';

    if (!list || list.length === 0) {
        container.innerHTML = `
            <div class="rayka-empty-state">
                <i class="fa-solid fa-box-open" style="font-size:32px; margin-bottom:10px;"></i>
                <p>No elevators registered yet.</p>
            </div>`;
        return;
    }

    list.forEach(item => {
        let totalFloors = 0;
        try {
            const parsedFloors = JSON.parse(item.floors);
            totalFloors = Object.keys(parsedFloors).length - 1;
        } catch (e) { totalFloors = 0; }

        container.innerHTML += `
            <div class="rayka-elevator-card">
                <div class="rayka-card-details">
                    <h4>${item.name} <span class="rayka-badge-job">${item.job}</span></h4>
                    <p><i class="fa-solid fa-building"></i> Connected Floors: ${totalFloors + 1}</p>
                </div>
                <div class="rayka-action-menu-container">
                    <button class="rayka-btn-dots" onclick="toggleContextMenu(event, ${item.id})">
                        <i class="fa-solid fa-ellipsis-vertical"></i>
                    </button>
                    <div class="asccochi-context-menu" id="asccochi-ctx-${item.id}">
                        <div class="asccochi-context-item" onclick="startEditElevator(${item.id})">
                            <i class="fa-solid fa-pen"></i> Edit
                        </div>
                        <div class="asccochi-context-item asccochi-delete-item" onclick="openDeleteModal(event, ${item.id})">
                            <i class="fa-solid fa-trash"></i> Delete
                        </div>
                    </div>
                </div>
            </div>
        `;
    });
}

function switchTab(targetId) {
    document.querySelectorAll('.rayka-tab-content').forEach(tab => tab.classList.remove('rayka-active-tab'));
    document.querySelectorAll('.rayka-menu-item').forEach(item => item.classList.remove('rayka-active'));

    document.getElementById(targetId).classList.add('rayka-active-tab');
    const activeBtn = Array.from(document.querySelectorAll('.rayka-menu-item')).find(btn => btn.getAttribute('data-target') === targetId);
    if (activeBtn) activeBtn.classList.add('rayka-active');
}

document.querySelectorAll('.rayka-menu-item').forEach(item => {
    item.addEventListener('click', () => {
        const target = item.getAttribute('data-target');
        if (target) switchTab(target);
    });
});

document.getElementById('rayka-search-input').addEventListener('input', (e) => {
    const val = e.target.value.toLowerCase();
    const filtered = globalElevatorsList.filter(item =>
        item.name.toLowerCase().includes(val) || item.job.toLowerCase().includes(val)
    );
    renderElevatorList(filtered);
});

function toggleContextMenu(event, id) {
    event.stopPropagation();
    const menu = document.getElementById(`asccochi-ctx-${id}`);
    const isOpen = menu && menu.style.display === 'block';
    document.querySelectorAll('[id^="asccochi-ctx-"]').forEach(m => m.style.display = 'none');
    if (menu && !isOpen) menu.style.display = 'block';
}

document.addEventListener('click', () => {
    document.querySelectorAll('[id^="asccochi-ctx-"]').forEach(m => m.style.display = 'none');
});

function teleportToFloor(elevatorId, floorKey) {
    document.getElementById('rayka-selector').classList.add('asccochi-hidden');
    fetch(`https://${GetParentResourceName()}/executeTeleport`, {
        method: 'POST',
        body: JSON.stringify({ id: elevatorId, floor: floorKey })
    });
}

function resetCreateForm() {
    document.getElementById('rayka-floors-section-wrapper').classList.add('asccochi-locked-phase');
    document.getElementById('rayka-floor-count').disabled = true;
    document.getElementById('rayka-btn-final-build').disabled = true;

    document.getElementById('rayka-elevator-name').disabled = false;
    document.getElementById('rayka-elevator-job').disabled = false;
    document.getElementById('rayka-elevator-name').value = "";
    document.getElementById('rayka-elevator-job').value = "";

    const mainInput = document.querySelector('.rayka-floor-custom-name[data-inputloc="main"]');
    if (mainInput) mainInput.value = "Main Entrance";

    const mainBtn = document.querySelector('.rayka-btn-set-loc[data-loc="main"]');
    if (mainBtn) mainBtn.disabled = true;

    savedLocations = { main: { name: "Main Entrance" } };
    editingElevatorId = null;
    document.getElementById('rayka-floor-count').value = 2;
    document.getElementById('rayka-btn-final-build').innerHTML = `<i class="fa-solid fa-circle-check"></i> Create Elevator`;
    document.getElementById('rayka-btn-confirm').innerHTML = `Confirm & Lock <i class="fa-solid fa-lock"></i>`;
    document.getElementById('rayka-btn-confirm').disabled = false;
    document.getElementById('rayka-dynamic-floors-list').innerHTML = '';
}

document.getElementById('rayka-btn-confirm').addEventListener('click', () => {
    const name = document.getElementById('rayka-elevator-name').value;
    const job = document.getElementById('rayka-elevator-job').value;
    if (!name || name.trim() === "") return;

    currentElevatorData.name = name;
    currentElevatorData.job = job.trim() === "" ? "public" : job.trim();

    const mainInput = document.querySelector('.rayka-floor-custom-name[data-inputloc="main"]');
    if (!savedLocations['main']) savedLocations['main'] = {};
    savedLocations['main'].name = mainInput ? mainInput.value : "Main Entrance";

    document.getElementById('rayka-elevator-name').disabled = true;
    document.getElementById('rayka-elevator-job').disabled = true;
    document.getElementById('rayka-btn-confirm').disabled = true;
    document.getElementById('rayka-btn-confirm').innerHTML = `Locked <i class="fa-solid fa-lock"></i>`;

    document.getElementById('rayka-floors-section-wrapper').classList.remove('asccochi-locked-phase');
    document.getElementById('rayka-floor-count').disabled = false;
    document.getElementById('rayka-btn-final-build').disabled = false;

    const mainBtn = document.querySelector('.rayka-btn-set-loc[data-loc="main"]');
    if (mainBtn) mainBtn.disabled = false;

    if (!editingElevatorId) {
        renderFloorsList(document.getElementById('rayka-floor-count').value);
    }
});

document.getElementById('rayka-floor-count').addEventListener('input', (e) => {
    let count = parseInt(e.target.value);
    if (count > 0) renderFloorsList(count);
});

function renderFloorsList(count) {
    const container = document.getElementById('rayka-dynamic-floors-list');
    if (!container) return;
    container.innerHTML = '';
    for (let i = 1; i <= count; i++) {
        let existingName = (savedLocations[i] && savedLocations[i].name) ? savedLocations[i].name : `Floor ${i}`;
        container.innerHTML += `
            <div class="rayka-location-row">
                <div class="rayka-row-inputs">
                    <i class="fa-solid fa-circle rayka-dot-floor"></i>
                    <input type="text" class="rayka-floor-custom-name" data-inputloc="${i}" value="${existingName}">
                </div>
                <button class="rayka-btn-set-loc" data-loc="${i}">Set Pos</button>
            </div>
        `;
    }
    setupLocationButtons();
    updateCheckmarks();
}

function setupLocationButtons() {
    document.querySelectorAll('.rayka-btn-set-loc').forEach(btn => {
        btn.onclick = function () {
            const locType = btn.getAttribute('data-loc');
            const inputEl = document.querySelector(`.rayka-floor-custom-name[data-inputloc="${locType}"]`);
            if (!savedLocations[locType]) savedLocations[locType] = {};
            savedLocations[locType].name = inputEl ? inputEl.value : `Floor ${locType}`;

            document.getElementById('rayka-container').classList.add('asccochi-hidden');
            fetch(`https://${GetParentResourceName()}/startSelectingLocation`, { method: 'POST', body: JSON.stringify({ locationIdentifier: locType }) });
        };
    });
}

function updateCheckmarks() {
    document.querySelectorAll('.rayka-btn-set-loc').forEach(btn => {
        const locType = btn.getAttribute('data-loc');
        if (savedLocations[locType] && savedLocations[locType].coords) {
            btn.classList.add('rayka-set-success');
            btn.innerText = "Saved ✓";
        } else {
            btn.classList.remove('rayka-set-success');
            btn.innerText = "Set Pos";
        }
    });
}

document.getElementById('rayka-btn-final-build').addEventListener('click', () => {
    document.querySelectorAll('.rayka-floor-custom-name').forEach(input => {
        const locType = input.getAttribute('data-inputloc');
        if (!savedLocations[locType]) savedLocations[locType] = {};
        savedLocations[locType].name = input.value;
    });

    fetch(`https://${GetParentResourceName()}/buildElevator`, {
        method: 'POST',
        body: JSON.stringify({
            id: editingElevatorId,
            meta: currentElevatorData,
            floors: savedLocations
        })
    });
    closeAllUI();
});

function startEditElevator(id) {
    const elevator = globalElevatorsList.find(e => e.id === id);
    if (!elevator) return;

    editingElevatorId = id;
    savedLocations = JSON.parse(elevator.floors);
    switchTab('rayka-create-section');

    document.getElementById('rayka-elevator-name').value = elevator.name;
    document.getElementById('rayka-elevator-job').value = elevator.job === "public" ? "" : elevator.job;

    currentElevatorData.name = elevator.name;
    currentElevatorData.job = elevator.job;

    const mainInput = document.querySelector('.rayka-floor-custom-name[data-inputloc="main"]');
    if (savedLocations['main'] && savedLocations['main'].name && mainInput) {
        mainInput.value = savedLocations['main'].name;
    }

    const floorCountCalculated = Object.keys(savedLocations).length - 1;
    document.getElementById('rayka-floor-count').value = floorCountCalculated > 0 ? floorCountCalculated : 1;

    renderFloorsList(document.getElementById('rayka-floor-count').value);

    document.getElementById('rayka-elevator-name').disabled = false;
    document.getElementById('rayka-elevator-job').disabled = false;
    document.getElementById('rayka-btn-confirm').disabled = false;
    document.getElementById('rayka-btn-confirm').innerHTML = `Confirm Changes <i class="fa-solid fa-lock-open"></i>`;

    document.getElementById('rayka-floors-section-wrapper').classList.remove('asccochi-locked-phase');
    document.getElementById('rayka-floor-count').disabled = false;
    document.getElementById('rayka-btn-final-build').disabled = false;

    const mainBtn = document.querySelector('.rayka-btn-set-loc[data-loc="main"]');
    if (mainBtn) mainBtn.disabled = false;

    document.getElementById('rayka-btn-final-build').innerHTML = `<i class="fa-solid fa-circle-check"></i> Save Changes`;
    updateCheckmarks();
}

function openDeleteModal(event, id) {
    event.stopPropagation();
    targetDeleteId = id;
    document.getElementById('asccochi-modal').classList.remove('asccochi-hidden');
    document.querySelectorAll('[id^="asccochi-ctx-"]').forEach(m => m.style.display = 'none');
}

document.getElementById('rayka-modal-cancel').addEventListener('click', () => {
    document.getElementById('asccochi-modal').classList.add('asccochi-hidden');
    targetDeleteId = null;
});

document.getElementById('rayka-modal-confirm-delete').addEventListener('click', () => {
    if (targetDeleteId) {
        fetch(`https://${GetParentResourceName()}/deleteElevator`, { method: 'POST', body: JSON.stringify({ id: targetDeleteId }) });
        closeAllUI();
    }
});

function closeAllUI() {
    document.getElementById('rayka-container').classList.add('asccochi-hidden');
    document.getElementById('asccochi-modal').classList.add('asccochi-hidden');
    document.getElementById('rayka-selector').classList.add('asccochi-hidden');
    fetch(`https://${GetParentResourceName()}/closeMenu`, { method: 'POST' });
}

window.addEventListener('keydown', (e) => { if (e.key === "Escape") closeAllUI(); });